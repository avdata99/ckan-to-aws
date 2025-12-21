#!/bin/bash -e
echo "Configuring s3filestore extension"

ckan config-tool ${CKAN_INI} "ckanext.s3filestore.aws_bucket_name = ${S3FILESTORE_AWS_BUCKET_NAME}"
ckan config-tool ${CKAN_INI} "ckanext.s3filestore.region_name = ${S3FILESTORE_REGION_NAME}"
ckan config-tool ${CKAN_INI} "ckanext.s3filestore.signature_version = s3v4"
ckan config-tool ${CKAN_INI} "ckanext.s3filestore.aws_access_key_id = ${S3FILESTORE_AWS_ACCESS_KEY_ID}"
ckan config-tool ${CKAN_INI} "ckanext.s3filestore.aws_secret_access_key = ${S3FILESTORE_AWS_SECRET_ACCESS_KEY}"
ckan config-tool ${CKAN_INI} "ckanext.s3filestore.acl = private"

# Created a bucket with acl Private
# Create Policy and call it ckan-s3-access-for-resources-and-images
# {
#     "Version": "2012-10-17",
#     "Statement": [
#         {
#             "Effect": "Allow",
#             "Action": [
#                 "s3:GetObject",
#                 "s3:PutObject",
#                 "s3:DeleteObject",
#                 "s3:ListBucket"
#             ],
#             "Resource": [
#                 "arn:aws:s3:::YOUR_BUCKET_NAME",
#                 "arn:aws:s3:::YOUR_BUCKET_NAME/*"
#             ]
#         }
#     ]
# }
# The create a IAM user: "ckan-s3-uploader", in the creation
# process, use "Attach existing policies directly" and select the policy created before.
# Then edit the user to generate Access Key ID and Secret Access Key.
# Then ensure adding these values to AWS secrets
#  - s3filestore_aws_bucket_name
#  - s3filestore_region_name
#  - s3filestore_aws_access_key_id
#  - s3filestore_aws_secret_access_key
