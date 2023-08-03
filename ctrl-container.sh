#!/bin/bash
# コンテナ操作スクリプト
#
# コマンド一覧
# purge                             : 全てのコンテナイメージを削除します
# lint                              : ruff による静的チェックを行います
# build                             : コンテナのビルド実行
# start [NAME_ENV]                  : コンテナの起動
# stop                              : コンテナの停止
# status                            : コンテナの状態確認
# login                             : コンテナへのログイン
# push [NAME_ENV]                   : コンテナイメージを ECR に push
# ecr_tagging [TARGET_TAG] [TO_TAG] : ECR 上のコンテナタグ更新
# set_prod_ecrtag                   : ECRのprodタグ を stgタグに移動
# ecs_dryrun [NAME_ENV]             : 環境変数ファイルの更新、タスク定義の更新確認
# ecs [NAME_ENV]                    : 環境変数ファイルの更新、タスク定義の更新
# start_service [NAME_ENV]          : ECS サービスの起動
# stop_service [NAME_ENV]           : ECS サービスの停止
# update_service [NAME_ENV]         : ECS サービスの再起動
export AWS_DEFAULT_REGION=ap-northeast-1

# 変数のセット
setting() {
  if [ -z "$1" ]; then #もし引数に値が入ってなければ
    NAME_ENV=stg
  else
    NAME_ENV=$1
  fi
  echo target env: $NAME_ENV 
  IMAGE_NAME=mot01
  CONTAINER_NAME=mot01
#  AWS_AccountID=`aws sts get-caller-identity|jq .Arn|sed -e 's/"//g'|cut -d ":" -f5`
#  DOMAIN=${AWS_AccountID}.dkr.ecr.ap-northeast-1.amazonaws.com
  PORT=8080
  CMD="/bin/bash"
#  CMD="uvicorn apimain:app --host 0.0.0.0 --port 8080"
  
  LATEST=latest
#  FILE_ENV=${IMAGE_NAME}/env-file/${NAME_ENV}.env
  FILE_ENV=env.txt
#  FILE_ECS=${IMAGE_NAME}/ecs_taskdef_${NAME_ENV}.json
#  S3_Path_ENV=s3://ecs-env-file-${AWS_AccountID}/${IMAGE_NAME}/${NAME_ENV}.env

#  CLUSTER_NAME=cluster01
#  SERVICE_NAME=${IMAGE_NAME}_${NAME_ENV}
#  TASKDEF_NAME=${IMAGE_NAME}_${NAME_ENV}
}

# コマンドチェック
check_command() {
  which jq
  if [ $? != 0 ]; then
    echo "command jq is not installed"
    exit -1
  fi
  which ruff
  if [ $? != 0 ]; then
    echo "command ruff is not installed"
    echo "pip3 install ruff"
  fi
}

# コンテナイメージの全削除
purge(){
  docker ps -qa|xargs docker rm -f
  docker images -qa|xargs docker rmi -f
  echo "--- docker images ---"
  docker images
  echo "--- docker processes ---"
  docker ps
}

# 静的チェック
lint() {
  result=$(ruff . 2>&1)
  if [[ $result ]]; then
    echo "ERROR : lint error detected."
    echo $result
  else
    exit 0
  fi
}

# コンテナのビルド
build() {
  if [ -f init.sh ]; then
    bash init.sh
  fi
#  aws ecr get-login-password --region ap-northeast-1 | docker login --username AWS --password-stdin ${DOMAIN}
  docker build -t ${IMAGE_NAME} .
}

# コンテナの起動
start() {
  echo "--- starting container  ---"
  DIR_LOCAL=`pwd`/app/
  DIR_CONTAINER=/usr/src/app/

  container_id=`docker ps -a |grep ${CONTAINER_NAME}|cut -d" " -f1`
  if [ "${container_id}" != "" ]; then 
    docker rm -f ${container_id}
  fi

  image_id=`docker images|grep ^${IMAGE_NAME}| sed -e 's/  */ /g'|cut -d" " -f3`
  #echo docker run -d --env-file env.txt --name ${IMAGE_NAME} ${image_id}
  echo docker run --env-file ${FILE_ENV} -p ${PORT}:${PORT} -v ${DIR_LOCAL}:${DIR_CONTAINER} --name ${CONTAINER_NAME} -itd ${image_id} ${CMD}
  docker run --env-file ${FILE_ENV} -p ${PORT}:${PORT} -v ${DIR_LOCAL}:${DIR_CONTAINER} --name ${CONTAINER_NAME} -itd ${image_id} ${CMD}
  echo ""
  docker logs ${CONTAINER_NAME}
}

# コンテナの停止
stop() {
  echo "--- stopping container  ---"
  container_id=`docker ps -a |grep ${CONTAINER_NAME}|cut -d" " -f1`
  echo $container_id
  if [ "${container_id}" != "" ]; then
    docker stop ${container_id}
  fi
  echo ""
}

# コンテナの状態確認
status() {
  echo "--- check container status  ---"
  docker ps
  echo ""
}

login() {
  docker exec -it ${CONTAINER_NAME} bash
}

check_ecr_repo() {
  repository_name=$1
  
  aws ecr describe-repositories|jq .repositories[].repositoryUri
  repo=`aws ecr describe-repositories|jq .repositories[].repositoryUri | sed -e 's/"//g'|cut -d"/" -f2|grep ${repository_name}`
  if [ "$repo" == "" ] ; then
    echo "${repository_name} is not found."
    aws ecr create-repository --repository-name ${repository_name}
  else
    echo "${repository_name} is found."
  fi
}


# コンテナをECRにプッシュ
push() {
  check_ecr_repo ${IMAGE_NAME}
  URL_REPO=${DOMAIN}/${IMAGE_NAME}

  # 1. login
  aws ecr get-login-password --region ap-northeast-1 | docker login --username AWS --password-stdin ${DOMAIN}

  # 2. tagging
  echo docker tag ${IMAGE_NAME}:${LATEST} ${URL_REPO}:${LATEST}
  docker tag ${IMAGE_NAME}:${LATEST} ${URL_REPO}:${LATEST}

  # 3. register to ECR
  echo docker push ${URL_REPO}:${LATEST}
  docker push ${URL_REPO}:${LATEST}

  ecr_tagging ${NAME_ENV}_bak ${NAME_ENV}
  ecr_tagging ${NAME_ENV} ${LATEST}
}

ecr_tagging() {
  FROM_DIGEST=$(aws ecr list-images --repository-name ${IMAGE_NAME} --query "imageIds[?imageTag=='$1'] | [0].imageDigest")
  TO_DIGEST=$(aws ecr list-images --repository-name ${IMAGE_NAME} --query "imageIds[?imageTag=='$2'] | [0].imageDigest")
  if [[ "$FROM_DIGEST" = "$TO_DIGEST" ]]
  then
    # 既にコピー元とコピー先が同じダイジェストの場合は何もしない
    echo "Tag already same. Skipped."
  else
    # リモートでタグをコピー
    echo "ecr tag copy: ${1} => ${2}"
    # https://docs.aws.amazon.com/cli/latest/reference/ecr/batch-get-image.html
    MANIFEST=$(aws ecr batch-get-image --repository-name ${IMAGE_NAME} --image-ids imageTag=$2 --query 'images[].imageManifest' --output text)

    # https://docs.aws.amazon.com/cli/latest/reference/ecr/put-image.html
    aws ecr put-image --repository-name ${IMAGE_NAME} --image-tag $1 --image-manifest "$MANIFEST"
  fi
}

# ECRのprodタグをstgタグの位置に揃える
set_prod_ecrtag() {
  # 1. login
  aws ecr get-login-password --region ap-northeast-1 | docker login --username AWS --password-stdin ${DOMAIN} 

  ecr_tagging prod_bak prod
  ecr_tagging prod stg
}

# ECS task の登録のドライラン
register_ecs_task_dryrun() {
  aws s3 cp ${FILE_ENV} ${S3_Path_ENV}
  aws ecs register-task-definition --family fargate-efs-mount-test --cli-input-json file://${FILE_ECS}
}

# ECS task の登録
register_ecs_task() {
  aws s3 cp ${FILE_ENV} ${S3_Path_ENV}
  aws ecs register-task-definition --cli-input-json file://${FILE_ECS}
}

# サービス開始
start_service(){
    echo aws ecs update-service --cluster ${CLUSTER_NAME} --service ${SERVICE_NAME} --task-definition ${TASKDEF_NAME} --desired-count 1
    aws ecs update-service --cluster ${CLUSTER_NAME} --service ${SERVICE_NAME} --task-definition ${TASKDEF_NAME} --desired-count 1
}

# サービス停止
stop_service(){
    echo aws ecs update-service --cluster ${CLUSTER_NAME} --service ${SERVICE_NAME} --desired-count 0
    aws ecs update-service --cluster ${CLUSTER_NAME} --service ${SERVICE_NAME} --desired-count 0
}

# サービス強制更新
update_service(){
    #ECRだけ変わってServiceの再起動だけしたい時 --force-new-deploymentをつけて強制的にサービスのタスク再起動する
    echo     aws ecs update-service --cluster ${CLUSTER_NAME} --service  ${SERVICE_NAME} --force-new-deployment --task-definition ${TASKDEF_NAME}
    aws ecs update-service --cluster ${CLUSTER_NAME} --service  ${SERVICE_NAME} --force-new-deployment --task-definition ${TASKDEF_NAME}
}

usage() {
cat <<EOUSAGE
-----------------------------------------------------------------
Usage: $0 [command] [arg1] [arg2]....

command:  [start|stop|restart|status|build|push|ecs_dryrun|ecs|login|ecr_tagging]

command detail:
 purge                             : 全てのコンテナイメージを削除します
 lint                              : ruff による静的チェックを行います
 build                             : コンテナのビルド実行
 start [NAME_ENV]                  : コンテナの起動
 stop                              : コンテナの停止
 status                            : コンテナの状態確認
 login                             : コンテナへのログイン
 push [NAME_ENV]                   : コンテナイメージを ECR に push
 ecr_tagging [TARGET_TAG] [TO_TAG] : ECR 上のコンテナタグ更新
 set_prod_ecrtag                   : ECRのprodタグ を stgタグに移動
 ecs_dryrun [NAME_ENV]             : 環境変数ファイルの更新、タスク定義の更新確認
 ecs [NAME_ENV]                    : 環境変数ファイルの更新、タスク定義の更新
 start_service [NAME_ENV]          : ECS サービスの起動
 stop_service [NAME_ENV]           : ECS サービスの停止
 update_service [NAME_ENV]         : ECS サービスの再起動
------------------------------------------------------------------
EOUSAGE
}

case $1 in
purge)
  purge
  ;;
lint)
  lint
  ;;
build)
  setting
  build
  ;;
start)
  setting $2
  stop
  start
  status
  ;;
stop)
  setting
  stop
  status
  ;;
status)
  setting
  status
  ;;
restart)
  setting $2
  stop
  start
  status
  ;;
login)
  setting $2
  login
  ;;
push)
  setting $2
  push
  ;;
ecr_tagging)
  setting $2
  ecr_tagging $2 $3
  ;;
set_prod_ecrtag)
  setting
  set_prod_ecrtag $2 $3
  ;;
ecs_dryrun)
  setting $2
  register_ecs_task_dryrun
  ;;
ecs)
  setting $2
  register_ecs_task
  ;;
start_service) # サービス開始
  setting $2
  start_service
  ;;
stop_service) # サービス停止
  setting $2
  stop_service
  ;;
update_service) # サービス停止
  setting $2
  update_service
  ;;
*)
  usage
  ;;
esac
exit 0

