package e2e_test

import (
	"testing"
	"time"

	"github.com/defenseunicorns/delivery_aws_iac_utils/pkg/utils"
	"github.com/gruntwork-io/terratest/modules/terraform"
	teststructure "github.com/gruntwork-io/terratest/modules/test-structure"
)

func TestExamplesCompleteCommon(t *testing.T) {
	t.Parallel()

	// Generate a random hex string to use as the name prefix for name conflicts
	randomHex := utils.GenerateRandomHex(2)

	// Set environment variables if not already set
	utils.SetDefaultEnvVar("TF_VAR_region", "us-east-2")
	utils.SetDefaultEnvVar("TF_VAR_name_prefix", "ci-"+randomHex)

	tempFolder := teststructure.CopyTerraformFolderToTemp(t, "../..", "examples/complete")
	terraformOptions := &terraform.Options{
		TerraformBinary: "tofu",
		TerraformDir:    tempFolder,
		Upgrade:         false,
		VarFiles: []string{
			"../../examples/complete/fixtures.common.tfvars",
		},
		RetryableTerraformErrors: map[string]string{
			".*": "Failed to apply Terraform configuration due to an error.",
		},
		MaxRetries:         5,
		TimeBetweenRetries: 5 * time.Second,
	}

	// Defer the teardown
	defer func() {
		t.Helper()
		teststructure.RunTestStage(t, "TEARDOWN", func() {
			terraform.Destroy(t, terraformOptions)
		})
	}()

	// Set up the infra
	teststructure.RunTestStage(t, "SETUP", func() {
		terraform.InitAndApply(t, terraformOptions)
	})

	// Run assertions
	teststructure.RunTestStage(t, "TEST", func() {
		// Assertions go here
	})
}
