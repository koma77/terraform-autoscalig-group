import json
import boto3

def lambda_handler(event, context):
    message = json.loads(event['Records'][0]['Sns']['Message'])
    deployment_id = message['deploymentId']
    client = boto3.client('codedeploy', region_name='ap-southeast-1')
    deployment = client.get_deployment(deploymentId=deployment_id)
    zip = deployment['deploymentInfo']['revision']['s3Location']['key']
    print("Deployment ID: {} File: {}".format(deployment_id, zip))
    clients3 = boto3.client('s3', region_name='ap-southeast-1')
    clients3.put_object(Body=zip, Bucket='deploy-lab', Key='last-successful-deploy.txt')
    return True
