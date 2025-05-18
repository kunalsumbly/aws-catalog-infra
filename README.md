aws ecs list-tasks \
--cluster springboot-ecs-cluster \
--service-name busybox-az1

aws ecs execute-command \
--no-verify-ssl \
--cluster springboot-ecs-cluster \
--task arn:aws:ecs:ap-southeast-2:721431533455:task/springboot-ecs-cluster/b943cf5fe916492fb5872a32218d5977 \
--container busybox \
--command "wget -qO- http://springboot-app-lb-2020179555.ap-southeast-2.elb.amazonaws.com:8888/actuator/health" \
--interactive


terraform plan -var-file="image-tags.tfvars"

terraform apply -var-file="image-tags.tfvars" -auto-approve


aws ecs execute-command \
--no-verify-ssl \
--cluster springboot-ecs-cluster \
--task arn:aws:ecs:ap-southeast-2:721431533455:task/springboot-ecs-cluster/b943cf5fe916492fb5872a32218d5977 \
--container busybox \
--command "wget -qO- http://springboot-app-lb-2020179555.ap-southeast-2.elb.amazonaws.com:8888/actuator/health" \
--interactive

# role arn
arn:aws:iam::721431533455:role/ecsTaskExecutionRole


# register a task definition image for busy box 
aws ecs register-task-definition \
--family ssm-shell \
--network-mode awsvpc \
--requires-compatibilities FARGATE \
--cpu 256 \
--memory 512 \
--execution-role-arn arn:aws:iam::721431533455:role/ecsTaskExecutionRole \
--task-role-arn arn:aws:iam::721431533455:role/ecsTaskExecutionRole \
--container-definitions '[
{
"name": "ssm-shell",
"image": "public.ecr.aws/amazonlinux/amazonlinux:2",
"essential": true,
"command": ["sh", "-c", "yum install -y curl; while true; do sleep 3600; done"],
"logConfiguration": {
"logDriver": "awslogs",
"options": {
"awslogs-group": "/ecs/ssm-shell",
"awslogs-region": "ap-southeast-2",
"awslogs-stream-prefix": "ecs"
}
}
}
]' \
--no-verify-ssl

#!/bin/bash
# config service subnet details
aws ecs run-task \
--cluster springboot-ecs-cluster \
--launch-type FARGATE \
--enable-execute-command \
--task-definition ssm-shell \
--network-configuration "awsvpcConfiguration={subnets=[subnet-0ec4aeb6db36c11ac],securityGroups=[sg-01a56516040e25b06],assignPublicIp=ENABLED}" \
--no-verify-ssl



aws ecs run-task \
--cluster springboot-ecs-cluster \
--launch-type FARGATE \
--enable-execute-command \
--task-definition ssm-shell \
--network-configuration "awsvpcConfiguration={subnets=[subnet-0cb57206288885575],securityGroups=[sg-01a56516040e25b06],assignPublicIp=ENABLED}" \
--no-verify-ssl

# get the status of the task 
aws ecs list-tasks \
--cluster springboot-ecs-cluster \
--desired-status RUNNING \
--family ssm-shell \
--no-verify-ssl

aws ecs list-tasks --cluster springboot-ecs-cluster --family ssm-shell --no-verify-ssl

# Use the task ARN from above
aws ecs stop-task \
--cluster springboot-ecs-cluster \
--task arn:aws:ecs:ap-southeast-2:721431533455:task/springboot-ecs-cluster/b8ed4ba5beb744fa89fe0f2631adeff0 \
--no-verify-ssl

aws ecs describe-tasks \
--cluster springboot-ecs-cluster \
--task arn:aws:ecs:ap-southeast-2:721431533455:task/springboot-ecs-cluster/971ea1110984496d9dc9cde5cc65fb4f \
--no-verify-ssl

# shell into container
aws ecs execute-command \
--no-verify-ssl \
--cluster springboot-ecs-cluster \
--task arn:aws:ecs:ap-southeast-2:721431533455:task/springboot-ecs-cluster/060244fe0ade48bf89e965eaa6f7b5dc \
--container ssm-shell \
--command "/bin/sh" \
--interactive


# curl commands for ssm shell
curl -v http://10.0.2.152:8888/actuator/health


# plan and apply
terraform plan -var-file="params.tfvars"

terraform apply -var-file="params.tfvars" -auto-approve
terraform destroy -var-file="params.tfvars"


# terraform delete resource 

terraform destroy -target aws_s3_bucket.example

# remove from terrafrom state
terraform state rm aws_ecs_service.config

aws s3 cp catalog-service-prod.properties s3://test-kunal-pii-logs --no-verify-ssl

# netcat 
nc -zv b-7b8f5b10-b4eb-428b-90a8-f477df4eb6ba.mq.ap-southeast-2.on.aws 5671
amqps://b-d16e12f7-ce12-4cfb-b764-6922c1e205d4.mq.ap-southeast-2.on.aws:5671

# aws ecs rabbit mq thread
https://www.reddit.com/r/aws/comments/1j82g6u/does_ecs_service_connect_work_with_tcp_and_amqp/

# server driven ui
https://www.youtube.com/watch?v=nk6n1XFDn9c
https://creators.spotify.com/pod/profile/front-end-happy-hour/episodes/Episode-146---Sidebar-interview-with-Jem-Young-e2omgmq/a-abhptt8
can you generate me a spring boot working project with
- controllers
- models
- Template/Component Registry
- Schema Contracts
- Reusability and Modular Design
- capability negotiation
- Automation
  that generate the specific movie details page. Please choose simple example, but I want to implement it end to end. e.g I will use a ui template v1 and then marry it with data to produce a consolidated output. 
- Progressively we could use ui template v2 with some changes , but still taking to the  Movie Data API for the movie’s info, User Profile API for user-specific data (like whether the movie is in “My List”), 
  and Recommendations API for related titles
- I would assume that ui layout template will have more versions than the Data APIs. 
  - different ui layout template versions would be talking to same Data APIs e.g movie data API v1
  - also ui layout template v2 could be talking to a specific movie data API v2 version
  

