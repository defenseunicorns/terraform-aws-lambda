import boto3
import urllib.request
import urllib.error
import json
import logging
import os
from urllib.parse import urlparse
from datetime import datetime, timedelta

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def lambda_handler(event, context):
    # Log the entire event object as a JSON string
    logger.info(f"Received event: {json.dumps(event)}")

    arn = event['SecretId']
    token = event['ClientRequestToken']
    step = event['Step']

    service_client = boto3.client('secretsmanager', endpoint_url=os.environ.get('SECRETS_MANAGER_ENDPOINT'))
    ssm_client = boto3.client('ssm', endpoint_url=os.environ.get('SSM_ENDPOINT'))

    try:
        metadata = service_client.describe_secret(SecretId=arn)
        if not metadata['RotationEnabled']:
            raise ValueError(f"Secret {arn} is not enabled for rotation")

        versions = metadata['VersionIdsToStages']
        if token not in versions:
            raise ValueError(f"Secret version {token} has no stage for rotation of secret {arn}")

        if "AWSPENDING" not in versions[token]:
            raise ValueError(f"Secret version {token} not set as AWSPENDING for rotation of secret {arn}")

        if step == "createSecret":
            create_secret(service_client, arn, token)
        elif step == "setSecret":
            logger.info(f"Step: {step} - nothing to do, moving to next step")
        elif step == "testSecret":
            logger.info(f"Step: {step} - nothing to do, moving to next step")
        elif step == "finishSecret":
            finish_secret(service_client, arn, token)
            update_ec2_instances(ssm_client, arn)

            # Generic success message for notification
            send_notification("Secret rotation process completed successfully", context)
            logger.info(f"{context.function_name}: Successfully completed all steps in secret rotation")
            return {"statusCode": 200, "body": json.dumps("Function executed successfully!")}
        else:
            raise ValueError("Invalid step parameter")

    except Exception as e:
        current_epoch = int(datetime.now().timestamp())
        seven_days_ago_epoch = int((datetime.now() - timedelta(days=7)).timestamp())

        aws_cli_command = (
            f"aws logs get-query-results --query-id $(aws logs start-query "
            f"--log-group-name \"{context.log_group_name}\" "
            f"--start-time {seven_days_ago_epoch} "
            f"--end-time {current_epoch} "
            f"--query-string 'fields @timestamp, @message | filter @requestId like /{context.aws_request_id}/ | sort @timestamp desc | limit 20' | jq -r .queryId && sleep 5)"
        )

        logs_error_message = (
            f"Error in secret rotation process:\n"
            f"Lambda Function: {context.function_name}\n"
            f"AWS Request ID: {context.aws_request_id}\n"
            f"Log Group Name: {context.log_group_name}\n"
            f"Exception: {str(e)}"
        )
        notification_error_message = (
            "Error in secret rotation process:\n"
            f"Lambda Function: {context.function_name}\n"
            f"AWS Request ID: {context.aws_request_id}\n"
            f"Log Group Name: {context.log_group_name}\n"
            f"Log Stream Name: {context.log_stream_name}\n"
            "Run this command to fetch logs:\n\n"
            f"{aws_cli_command}"
        )
        # Generic error message for notification, detailed log for internal use
        send_notification(notification_error_message, context)
        logger.error(logs_error_message)
        return {"statusCode": 500, "body": json.dumps("An error occurred during function execution.")}

def create_secret(service_client, arn, token):
    """Create the secret

    This method first checks for the existence of a secret for the passed in token. If one does not exist, it will generate a
    new secret and put it with the passed in token, structured as JSON with user names as keys.

    Args:
        service_client (client): The secrets manager service client
        arn (string): The secret ARN or other identifier
        token (string): The ClientRequestToken associated with the secret version

    """
    # Get users from the environment variable and split it into a list
    users = os.environ.get('USERS', 'ec2-user').split(',')

    # Ensure the current secret exists
    service_client.get_secret_value(SecretId=arn, VersionStage="AWSCURRENT")

    # Try to retrieve the secret version, put a new secret if that fails
    try:
        service_client.get_secret_value(SecretId=arn, VersionId=token, VersionStage="AWSPENDING")
        logger.info("createSecret: Successfully retrieved secret for %s." % arn)
    except service_client.exceptions.ResourceNotFoundException:
        # Generate a new password for each user
        secret_data = {}
        exclude_characters = os.environ.get('EXCLUDE_CHARACTERS', '/@"\'\\')
        for user in users:
            passwd = service_client.get_random_password(ExcludeCharacters=exclude_characters)
            secret_data[user] = passwd['RandomPassword']

        # Put the secret with multiple user passwords
        service_client.put_secret_value(
            SecretId=arn,
            ClientRequestToken=token,
            SecretString=json.dumps(secret_data),
            VersionStages=['AWSPENDING']
        )
        logger.info("createSecret: Successfully put secret for ARN %s and version %s." % (arn, token))

def finish_secret(service_client, arn, token):
    """Finish the secret

    This method finalizes the rotation process by marking the secret version passed in as the AWSCURRENT secret and then updates EC2 instances.

    Args:
        service_client (client): The secrets manager service client
        arn (string): The secret ARN or other identifier
        token (string): The ClientRequestToken associated with the secret version

    Raises:
        ResourceNotFoundException: If the secret with the specified arn does not exist

    """
    # First describe the secret to get the current version
    metadata = service_client.describe_secret(SecretId=arn)
    current_version = None
    for version in metadata["VersionIdsToStages"]:
        if "AWSCURRENT" in metadata["VersionIdsToStages"][version]:
            if version == token:
                # The correct version is already marked as current, return
                logger.info("finishSecret: Version %s already marked as AWSCURRENT for %s" % (version, arn))
                return
            current_version = version
            break

    # Finalize by staging the secret version as current
    service_client.update_secret_version_stage(SecretId=arn, VersionStage="AWSCURRENT", MoveToVersionId=token, RemoveFromVersionId=current_version)
    logger.info("finishSecret: Successfully set AWSCURRENT stage to version %s for secret %s." % (token, arn))

def update_ec2_instances(ssm_client, secret_arn):
    """Update EC2 instances configurations for multiple users by running commands via AWS SSM.

    Args:
        ssm_client (client): The SSM service client
        secret_arn (string): The ARN of the secret that has been rotated
    """
    # Fetch and log the users involved in the update
    users = os.environ.get('USERS', 'ec2-user').split(',')
    logger.info(f"Updating passwords for users: {users}")

    # Fetch and log the rotation tags from environment variables
    rotation_tag_key = os.environ.get('ROTATION_TAG_KEY', 'Password-Rotation')
    rotation_tag_value = os.environ.get('ROTATION_TAG_VALUE', 'true')
    logger.info(f"Using tag '{rotation_tag_key}' with value '{rotation_tag_value}' for identifying EC2 instances.")

    # Fetch EC2 instances with the specific tag and log the findings
    ec2_client = boto3.client('ec2')
    response = ec2_client.describe_instances(
        Filters=[
            {'Name': f"tag:{rotation_tag_key}", 'Values': [rotation_tag_value]},
            {'Name': 'instance-state-name', 'Values': ['running']}
        ]
    )
    instance_ids = [instance['InstanceId'] for reservation in response['Reservations'] for instance in reservation['Instances']]
    if not instance_ids:
        logger.warning(f"No EC2 instances with the tag '{rotation_tag_key}: {rotation_tag_value}' were found.")
        return
    logger.info(f"Found EC2 instances with tag '{rotation_tag_key}: {rotation_tag_value}': {instance_ids}")

    # Prepare commands to execute for each user
    command_template = (
        "aws secretsmanager get-secret-value --secret-id {secret_arn} --query 'SecretString' --output text | "
        "jq -r '.\"{user}\"' | sudo passwd {user} --stdin"
    )
    commands = [command_template.format(secret_arn=secret_arn, user=user) for user in users]
    logger.info(f"Commands prepared for execution: {commands}")

    # Execute the commands on each instance via SSM
    try:
        response = ssm_client.send_command(
            InstanceIds=instance_ids,
            DocumentName="AWS-RunShellScript",
            Parameters={'commands': commands},
            Comment='Update EC2 user passwords with new secret'
        )
        logger.info(f"SSM command sent successfully\nCommandId: {response['Command']['CommandId']}\nInstanceIds: {response['Command']['InstanceIds']}")
    except Exception as e:
        logger.error(f"Failed to send SSM command: {str(e)}")

def valid_url(url):
    """ Validate the URL to ensure it is well-formed. """
    try:
        result = urlparse(url)
        return all([result.scheme, result.netloc])
    except ValueError:
        return False

def send_notification(message, context):
    """Send a generic notification message to the specified webhook URL."""
    webhook_url = os.environ.get("NOTIFICATION_WEBHOOK_URL")
    if webhook_url and valid_url(webhook_url):
        headers = {"Content-Type": "application/json"}
        data = json.dumps({"text": message}).encode('utf-8')
        req = urllib.request.Request(webhook_url, data=data, headers=headers, method='POST')
        try:
            with urllib.request.urlopen(req) as response:
                response_body = response.read().decode('utf-8')
                if response.status != 200:
                    logger.error(f"Failed to send notification. Status Code: {response.status}, Response: {response_body}")
                else:
                    logger.info("Notification sent successfully.")
        except urllib.error.HTTPError as e:
            # Handles HTTP errors
            logger.error(f"Failed to send notification. HTTP Error Code: {e.code}, Response: {e.read().decode()}")
        except urllib.error.URLError as e:
            # Handles URL errors (e.g., network issues)
            logger.error(f"Failed to send notification. URL Error: {e.reason}")
    else:
        logger.info("Webhook URL is invalid or not provided. Skipping notification.")
