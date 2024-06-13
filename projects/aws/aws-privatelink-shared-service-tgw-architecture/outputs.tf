output "access_ec2" {
  description = "Use SSM to access your Shared Service EC2 instance"
  value = <<-EOT
    Run the following:
       
      Shared Service EC2 instance: 
      aws ssm start-session --target ${module.systems_manager.amazon_linux_id}

      Application EC2 instance:
      aws ssm start-session --target ${module.systems_manager_application.amazon_linux_id}

      You must have AWS CLI installed and configured on your local machine to run this command. 
      If you get an error saying "SessionManagerPlugin is not found", you will also need to install the plugin on your computer. 
      See: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html

    To test connectivity:

      openssl s_client -connect ${replace(module.cluster.bootstrap_endpoint, "SASL_SSL://", "")}    

   EOT
}