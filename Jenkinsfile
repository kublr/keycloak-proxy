#!groovy

@NonCPS
static def summarizeBuild(b) {
    b.changeSets.collect { cs ->
        /Changes: / + cs.collect { entry ->
            / — ${entry.msg} by ${entry.author.fullName} /
        }.join('\n')
    }.join('\n')
}

def srcVersion = null
def publishVersion = null
def gitCommit = null
def gitBranch = null
def releaseBranches = ['master']
def releaseBuild = false
def quickBuild = false
def gitTaggerEmail = 'nloskutov@eastbanctech.com'
def gitTaggerName = 'Nikita Loskutov'

podTemplate(
        label: 'kublrdockerimage',
        containers: [
                containerTemplate(name: 'jnlp', image: 'jenkinsci/jnlp-slave', args: '${computer.jnlpmac} ${computer.name}'),
                containerTemplate(name: 'docker', ttyEnabled: true, command: 'cat', args: '-v',
                        image: 'nexus.build.svc.cluster.local:5000/jenkinsci/jnlp-slave-ext:0.1.9')
        ],
        volumes: [
                // this is necessary for docker build to work
                hostPathVolume(hostPath: '/run/docker.sock', mountPath: '/run/docker.sock')
        ]) {
    node('kublrdockerimage') {
        String buildStatus = 'Success'
        try {
            stage('build-publish') {
                sh "mkdir -p ${HOME}/go/src/github.com/kublr/keycloak-proxy"
                dir("${HOME}/go/src/github.com/kublr/keycloak-proxy") {
                    // checkout source
                    checkout scm

                    // get current version from the source code
                    srcVersion = sh returnStdout: true, script: '. ./main.properties; echo -n ${VERSION}'
                    srcVersion = srcVersion.trim()

                    // fail if version is not found for any reason
                    if (srcVersion == "") {
                        error "Image version is not specified in main.properties"
                    }

                    // get git commit hash
                    gitCommit = sh returnStdout: true, script: 'git rev-parse HEAD'
                    gitCommit = gitCommit.trim()

                    // git branch name is taken from an env var for multi-branch pipeline project, or from git for other projects
                    gitBranch = sh returnStdout: true, script: 'git rev-parse --abbrev-ref HEAD'
                    gitBranch = gitBranch.trim()

                    // branch qualifier for use in tag
                    def branchQual = gitBranch.replaceAll('[^a-zA-Z0-9]', '_')
                    branchQual = branchQual.length() <= 32 ? branchQual : branchQual.substring(branchQual.length() - 32, branchQual.length())

                    // tag names are generated in different ways for release and non-release branches
                    releaseBuild = (gitBranch in releaseBranches)

                    // we need only release builds for the project
                    // publishVersion = releaseBuild ? srcVersion : "${srcVersion}-${branchQual}.${BUILD_NUMBER}"
                    publishVersion = srcVersion

                    // quick builds are not tested
                    quickBuild = gitBranch.startsWith('build/')

                    // running in 'docker' container because we need packer tool
                    container('docker') {
                        withCredentials([
                                usernamePassword(credentialsId: 'kublr-docker-hub', passwordVariable: 'REPO_PASSWORD', usernameVariable: 'REPO_USERNAME')
                        ]) {
                            // build and publish helm package
                            try {
                                sh """
                                docker login -u '${REPO_USERNAME}' -p '${REPO_PASSWORD}'

                                export PUBLISH_VERSION='${publishVersion}'

                                ./build.sh publish
                            """
                            } finally {
                                sh """
                                docker logout || true
                            """
                            }
                        }
                    }
                }
            }
            if (releaseBuild) {
                stage('tagging') {
                    echo 'Tagging phase'
                    sshagent(['kublr-jenkins-ci']) {
                        sh """
                        git config user.email '${gitTaggerEmail}'
                        git config user.name  '${gitTaggerName}'

                        git tag -a 'v${publishVersion}' -m 'passed CI'

                        mkdir -p ~/.ssh
                        echo 'Host *' >> ~/.ssh/config
                        echo 'BatchMode=yes' >> ~/.ssh/config
                        echo 'StrictHostKeyChecking=no' >> ~/.ssh/config

                        git push origin 'v${publishVersion}'
                    """
                    }
                }
            }
        } catch (Exception e) {
            currentBuild.result = 'Build Failed: ' + e
            buildStatus = "Failure: " + e
        } finally {
            stage('Slack notification') {
                // currentBuild.result will be null if no problem
                // or UNSTABLE if the JunitResultArchiver found failing tests
                String buildColor = currentBuild.result == null ? "#399E5A" : "#C03221"
                //configure emoji
                String buildEmoji = currentBuild.result == null ? ":ok_hand:" : ":thumbsdown:"
                String changes = summarizeBuild(currentBuild)

                slackMessage = "${buildEmoji} Build result for ${env.JOB_NAME} ${env.BRANCH_NAME} is: ${buildStatus}\n\n${changes}\n\nSee details at ${env.BUILD_URL}"

                slackSend color: buildColor, message: slackMessage
            }
        }

    }
}
