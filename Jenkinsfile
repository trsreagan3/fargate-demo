node {
    stage 'get repo'
       git clone  https://github.com/trsreagan3/fargate-demo ./fargate-demo
    stage 'enter repo'
       cd fargate-demo
    stage 'terraform init'
       terraform init
    stage 'terraform apply'
       terraform apply -auto-approve
}
