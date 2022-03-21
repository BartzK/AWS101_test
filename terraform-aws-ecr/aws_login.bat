set region=us-east-1
set aws_account_id=281738164247

aws ecr get-login-password --region %region% | docker login --username AWS --password-stdin %aws_account_id%.dkr.ecr.%region%.amazonaws.com

