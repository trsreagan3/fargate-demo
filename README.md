# hello world demo

This was completed in just under 3 hrs. There is still work to be done before it would be ready for serious use, but it is currently left as a single file due to lack of time. I did not have time to set up a jenkins instance to test the Jenkinsfile but I tried to lay out the steps. I also stored the state locally for simplicity and time. In a realistic scenario we would want state stored remotely.

AWS RESOURCES PROVISIONED
- vpc
- fargate ecs cluster
- alb
- fargate hello  world service
- cloudwatch vpc flow logs
- necessary IAM roles

TODO (if this was to become a serious service):
- break files up (network, fargate, service, logs)
- break vars in to separate file
- test Jenkinsfile
- remote state in s3 with dynamo for locking
- 1 private and 1 pub subnet per AZ
- run containers for this service in multiple AZ's
- service logging

ROLLING UPDATES
- fargate should handle most of this for us
- fargate will stand up new service containers next to current running containrs. At this point we can run healthchecks and automated/manual tests against the new containers. If the tests pass then we can direct traffic the new containers and drain and terminate  the old containers. Updates to the service would happen through new docker images being updated in the service config.

DEPLOYING
- requires terraform 0.12 or higher to be installed
- requires AWS credentials to be configured
- clone down repository
- cd terraform
- terraform init
- terraform apply -auto-approve
- when complete the URL for the service will be returned
- wait a minute or two  and then visit the URL to test for 200 response. You should see the nginx page.
- to destroy use terraform destroy





Your mission: To stand up and have a publicly-hosted end point available on port 8080 that we can access and get 200 response!

- 2-3 hours

- Use of load balancer 
  - Round robin or other demonstrated configuration
- Use of Security Groups
- Uses containers
- Terraform Use to Reproduce your work  
- Use of Jenkinsfile so that we can build and deploy your solution. If you're looking for a Jenkinsfile validator, one exists via https://job-dsl.herokuapp.com/)
- Repo documented with a README.md file 

Nice to have: 

- Logs routed to Cloudwatch
- Documentation on approach to shipping updates to the solution with minimal / no downtime
