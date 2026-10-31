# INDIVIDUAL CHECKS
# Local check with mongosh

```
$json = [System.IO.File]::ReadAllBytes((Join-Path $PWD.Path 'streamingapp.videos.json'))
$encoded = [Convert]::ToBase64String($json)
$script = "const docs = EJSON.parse(Buffer.from('$encoded', 'base64').toString('utf8')); db.videos.insertMany(docs).insertedIds.length"
docker compose exec -T mongo mongosh streamingapp --quiet --eval $script
```


# created .env with the below and then ran
```
docker compose up -d --force-recreate streaming

docker compose exec streaming node -e "for (const n of ['AWS_S3_BUCKET','AWS_ACCESS_KEY_ID','AWS_SECRET_ACCESS_KEY','AWS_SESSION_TOKEN']) console.log(n + '=' + (process.env[n] ? 'SET' : 'EMPTY'))"

docker compose logs --tail 50 streaming
```


# HELM
```
Updated values-local.yaml.example with aws region, bucketname

# powershell commands
$json = [System.IO.File]::ReadAllBytes((Join-Path $PWD.Path 'streamingapp.videos.json'))
$encoded = [Convert]::ToBase64String($json)
$script = "const docs = EJSON.parse(Buffer.from('$encoded', 'base64').toString('utf8')); db.videos.insertMany(docs).insertedIds.length"
kubectl -n streamingapp exec -i deployment/streamingapp-mongo -- mongosh streamingapp --quiet --eval $script


#bash
encoded=$(base64 < streamingapp.videos.json | tr -d '\r\n')
script="const docs = EJSON.parse(Buffer.from('$encoded', 'base64').toString('utf8')); db.videos.insertMany(docs).insertedIds.length"
kubectl -n streamingapp exec deployment/streamingapp-mongo -- mongosh streamingapp --quiet --eval "$script"

kubectl -n streamingapp exec deployment/streamingapp-mongo -- mongosh streamingapp --quiet --eval "db.videos.countDocuments()"

```

# HELM
Updated values-local.yaml.example with aws region, bucketname

# powershell commands
$json = [System.IO.File]::ReadAllBytes((Join-Path $PWD.Path 'streamingapp.videos.json'))
$encoded = [Convert]::ToBase64String($json)
$script = "const docs = EJSON.parse(Buffer.from('$encoded', 'base64').toString('utf8')); db.videos.insertMany(docs).insertedIds.length"
kubectl -n streamingapp exec -i deployment/streamingapp-mongo -- mongosh streamingapp --quiet --eval $script


#bash
encoded=$(base64 < streamingapp.videos.json | tr -d '\r\n')
script="const docs = EJSON.parse(Buffer.from('$encoded', 'base64').toString('utf8')); db.videos.insertMany(docs).insertedIds.length"
kubectl -n streamingapp exec deployment/streamingapp-mongo -- mongosh streamingapp --quiet --eval "$script"

kubectl -n streamingapp exec deployment/streamingapp-mongo -- mongosh streamingapp --quiet --eval "db.videos.countDocuments()"

#Helm - local - video from s3 bucket
export AWS_PROFILE="your-aws-sso-profile"
export EXPECTED_AWS_ACCOUNT_ID="your-aws-account-id"
export AWS_REGION="your-bucket-region"
export AWS_S3_BUCKET="your-local-dev-bucket-name"
export LOCAL_S3_ROLE_ARN="your-local-dev-s3-role-arn"

aws sso login --profile "$AWS_PROFILE"
./scripts/k8s-deploy.sh refresh-local-aws-credentials

kubectl -n streamingapp exec deployment/streamingapp-streaming -- printenv AWS_S3_BUCKET AWS_REGION

```