import boto3
import os
import time
import logging
from botocore.exceptions import ClientError, BotoCoreError

# Initialize AWS clients
ssm_client = boto3.client('ssm')
logs = boto3.client('logs')

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    # Ensure necessary environment variables are set
    if 'S3_BUCKET' not in os.environ:
        logger.error("Error: S3_BUCKET not defined")
        return

    logger.info(f"Environment variable S3_BUCKET={os.environ['S3_BUCKET']}")

    # Retrieve all log groups from CloudWatch
    log_groups = []
    extra_args = {}
    while True:
        try:
            dlg_response = logs.describe_log_groups(**extra_args)
            log_groups.extend(dlg_response.get('logGroups', []))
            if 'nextToken' not in dlg_response:
                break
            extra_args['nextToken'] = dlg_response['nextToken']
        except BotoCoreError as error:
            logger.error(f"Error describing log groups: {error}")
            break

    # Identify log groups to be exported based on tags
    log_groups_to_export = []
    for log_group in log_groups:
        try:
            if 'logGroupName' in log_group:
                response = logs.list_tags_log_group(logGroupName=log_group['logGroupName'])
                log_group_tags = response.get('tags', {})
                if log_group_tags.get('export') == 'true':
                    log_groups_to_export.append(log_group['logGroupName'])
            else:
                logger.warning("Invalid log group format encountered")
        except BotoCoreError as error:
            logger.error(f"Error listing tags for log group: {error}")

    # Constants for time calculations and retry mechanism
    HOURS_24_IN_MILLIS = 24 * 60 * 60 * 1000
    MAX_RETRIES = 10
    RETRY_WAIT_TIME = 5  # Seconds

    # Process each log group for export
    for log_group_name in log_groups_to_export:
        ssm_parameter_name = f"/log-exporter-last-export/{log_group_name}".replace("//", "/")

        try:
            # Retrieve last export time from SSM
            response = ssm_client.get_parameter(Name=ssm_parameter_name)
            last_export_value = int(response['Parameter']['Value'])
        except ssm_client.exceptions.ParameterNotFound:
            last_export_value = 0

        export_time = int(time.time() * 1000)
        logger.info(f"Exporting {log_group_name} to {os.environ['S3_BUCKET']}")

        # Check if 24 hours have passed since last export
        if export_time - last_export_value < HOURS_24_IN_MILLIS:
            logger.info("    Skipped until 24hrs from last export is completed")
            continue

        # Attempt to create export task with retries for rate limits
        retries = MAX_RETRIES
        while retries > 0:
            try:
                response = logs.create_export_task(
                    taskName=f"export-{log_group_name}-{export_time}",
                    logGroupName=log_group_name,
                    fromTime=last_export_value,
                    to=export_time,
                    destination=os.environ['S3_BUCKET'],
                    destinationPrefix=log_group_name
                )
                logger.info(f"Task created: {response['taskId']}")
                ssm_client.put_parameter(
                    Name=ssm_parameter_name,
                    Value=str(export_time),
                    Type='String',
                    Overwrite=True
                )
                break
            except ClientError as e:
                if e.response['Error']['Code'] == 'LimitExceededException':
                    logger.info("    LimitExceededException, waiting 5 seconds and retrying")
                    time.sleep(RETRY_WAIT_TIME)
                    retries -= 1
                else:
                    raise e
            if retries == 0:
                logger.error("Maximum retries reached, unable to create export task.")

        # End of for loop for log_groups_to_export

# End of lambda_handler function
