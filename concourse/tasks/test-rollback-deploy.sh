#!/bin/bash

set -o errexit

export ROOT_FOLDER=$( pwd )
export REPO_RESOURCE=repo
export TOOLS_RESOURCE=tools
export VERSION_RESOURCE=version
export OUTPUT_RESOURCE=out

echo "Root folder is [${ROOT_FOLDER}]"
echo "Repo resource folder is [${REPO_RESOURCE}]"
echo "Tools resource folder is [${TOOLS_RESOURCE}]"
echo "Version resource folder is [${VERSION_RESOURCE}]"

source ./pipeline.sh

echo "Deploying the built application on test environment"
cd ${ROOT_FOLDER}/${REPO_RESOURCE}

#--------------------------------

__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

[[ -f "${__DIR}/pipeline.sh" ]] && source "${__DIR}/pipeline.sh" || \
    echo "No pipeline.sh found"

echo "Running retrieval of group and artifactid to download all dependencies. It might take a while..."
projectGroupId=$( retrieveGroupId )
projectArtifactId=$( retrieveArtifactId )

rm -rf ${OUTPUT_FOLDER}/test.properties
# Find latest prod version
LATEST_PROD_TAG=$( findLatestProdTag )
echo "Last prod tag equals ${LATEST_PROD_TAG}"
if [[ -z "${LATEST_PROD_TAG}" ]]; then
    echo "No prod release took place - skipping this step"
else
    # Downloading latest jar
    LATEST_PROD_VERSION=${LATEST_PROD_TAG#prod/}
    echo "Last prod version equals ${LATEST_PROD_VERSION}"
    downloadJar 'true' ${REPO_WITH_JARS} ${projectGroupId} ${projectArtifactId} ${LATEST_PROD_VERSION}
    logInToCf "${REDOWNLOAD_INFRA}" "${CF_TEST_USERNAME}" "${CF_TEST_PASSWORD}" "${CF_TEST_ORG}" "${CF_TEST_SPACE}" "${CF_TEST_API_URL}"
    deployAndRestartAppWithNameForSmokeTests ${projectArtifactId} "${projectArtifactId}-${LATEST_PROD_VERSION}"
    propagatePropertiesForTests ${projectArtifactId}
    # Adding latest prod tag
    echo "LATEST_PROD_TAG=${LATEST_PROD_TAG}" >> ${OUTPUT_FOLDER}/test.properties
fi

