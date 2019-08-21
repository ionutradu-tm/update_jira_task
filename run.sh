#!/bin/bash


#VARS:

TOKEN=$WERCKER_UPDATE_JIRA_TASK_TOKEN
VERSION=$WERCKER_UPDATE_JIRA_TASK_VERSION
PROJECT_NAME=$WERCKER_UPDATE_JIRA_TASK_PROJECT_NAME
TASK_IDS=$WERCKER_UPDATE_JIRA_TASK_TASK_IDS
STATUS_ID=$WERCKER_UPDATE_JIRA_TASK_STATUS_ID
STATUS_NAME=$WERCKER_UPDATE_JIRA_TASK_STATUS_NAME
JIRA_URL=$WERCKER_UPDATE_JIRA_TASK_JIRA_URL
JIRA_USER=$WERCKER_UPDATE_JIRA_TASK_JIRA_USER
JIRA_COMMENT=$WERCKER_UPDATE_JIRA_TASK_JIRA_COMMENT




#END_VARS


#FUNCTIONS

function create_version(){
    local TOKEN=$1
    local USER=$2
    local VERSION=$3
    local PROJECT_NAME=$4
    local URL=$5

    local CREATE_VERSION_URL=$URL"/rest/api/2/version"


    # generate create_version.json
    START_DATE=$(date +"%Y-%m-%d")
    echo -e "{\n}" >$WERCKER_OUTPUT_DIR/empty.json
    cat $WERCKER_OUTPUT_DIR/empty.json |
    jq 'setpath(["description"]; "")'|
    jq 'setpath(["name"]; "'"${VERSION}"'")'|
    jq 'setpath(["archived"]; "false")'|
    jq 'setpath(["released"]; "false")'|
    jq 'setpath(["startDate"]; "'"${START_DATE}"'")'|
    jq 'setpath(["project"]; "'"${PROJECT_NAME}"'")' > $WERCKER_OUTPUT_DIR/create_version.json

    #create version
    echo "curl -X POST --data @create_version.json $CREATE_VERSION_URL -H "Content-Type: application/json" --user $USER:$TOKEN"
    RESPONSE_CODE=$(curl --write-out %{http_code} --silent --output /dev/null -X POST --data @$WERCKER_OUTPUT_DIR/create_version.json $CREATE_VERSION_URL -H "Content-Type: application/json" --user $USER:$TOKEN)
    if [[ $RESPONSE_CODE != 201 ]];then
            echo "Error creating version $VERSION, ERROR_CODE: $RESPONSE_CODE"
            exit 2
    fi
    echo "Version $VERSION has been created successfully"


}

function get_status_id(){
    local TOKEN=$1
    local USER=$2
    local PROJECT_NAME=$3
    local TASK_ID=$4
    local STATUS_NAME=$5
    local URL=$6

    local CHECK_TASK_TRANSITIONS_URL=$URL"/rest/api/2/issue/"$TASK_ID"/transitions"
    curl --silent --output=$WERCKER_OUTPUT_DIR/task_details.json $CHECK_TASK_TRANSITIONS_URL --user $USER:$TOKEN
    export STATUS_ID=$(cat $WERCKER_OUTPUT_DIR/task_details.json|  jq -r '.transitions[] | select(.name=="'"${STATUS_NAME}"'")| .id')
    if [[ -n $STATUS_ID ]];then
        echo "FOUND ID $STATUS_ID for $STATUS_NAME"
    else
        echo "$STATUS_NAME is not a valid option for $TASK_ID"
    fi

}

function update_task_status(){
    local $TOKEN=$1
    local USER=$2
    local PROJECT_NAME=$3
    local TASK_ID=$4
    local STATUS_ID=$5
    local URL=$6
    local VERSION=$7
    local COMMENT=$8


    local local UPDATE_TASK_TRANSITIONS_URL=$URL"/rest/api/2/issue/"$TASK_ID"/transitions?expand=transitions.fields"

    cat $WERCKER_OUTPUT_DIR/empty.json |
    jq 'setpath(["update","comment",0,"add","body"]; "'"$COMMENT"'")'|
    jq 'setpath(["update","fixVersions",0,"add","name"]; "'"$VERSION"'")'|
    jq 'setpath(["transition","id"]; "'"$STATUS_ID"'")' > $WERCKER_OUTPUT_DIR/task_status_update.json
    echo "curl --write-out %{http_code} --silent --output /dev/null -X POST --data @$WERCKER_OUTPUT_DIR/task_status_update.json $UPDATE_TASK_TRANSITIONS -H "Content-Type: application/json" --user $USER:$TOKEN"
    RESPONSE_CODE=$(curl --write-out %{http_code} --silent --output /dev/null -X POST --data @$WERCKER_OUTPUT_DIR/task_status_update.json $UPDATE_TASK_TRANSITIONS -H "Content-Type: application/json" --user $USER:$TOKEN)
    if [[ $RESPONSE_CODE != 204 ]];then
        echo "Update status failed for TASK $TASK_ID, ERROR_CODE: $RESPONSE_CODE"
    fi
}
#END_FUNCTIONS

if [[ -z $STATUS_ID ]] && [[ -z $STATUS_NAME ]];then
    echo "STATUS_ID or STATUS_NAME should be set"
    exit 2
fi

if [[ -z $TOKEN ]];then
    echo "Please provide token"
fi

if [[ -z $JIRA_USER ]];then
    echo "Please provide Jira user"
fi

if [[ -z $JIRA_URL ]];then
    echo "Please provide Jira URL"
fi

if [[ -z $VERSION ]];then
    echo "Please provide version"
fi

if [[ -z $PROJECT_NAME ]];then
    echo "Please provide project name"
fi

if [[ -z $TASK_IDS ]];then
    echo "Please provide task IDs"
fi

JIRA_COMMENT=${JIRA_COMMENT:-"Status/fix version updated by wercker"}

echo "create_version $TOKEN $JIRA_USER $VERSION $PROJECT_NAME $JIRA_URL"
create_version $TOKEN $JIRA_USER $VERSION $PROJECT_NAME $JIRA_URL


for TASK_ID in $TASK_IDS
do

    if [[ -z $STATUS_ID ]];then
        get_status_id $TOKEN $JIRA_USER $PROJECT_NAME $TASK_ID $STATUS_NAME $JIRA_URL $JIRA_COMMENT
    fi
    update_task_status $TOKEN $JIRA_USER $PROJECT_NAME $TASK_ID $STATUS_ID $JIRA_URL $VERSION $JIRA_COMMENT
done