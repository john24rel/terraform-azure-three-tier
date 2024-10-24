pipeline {
    agent { 
        label 'ansible' 
    }

    options {
        skipDefaultCheckout()
    }

    stages {
        stage('Setup SSH Keys') {
            steps {
                sh '''
                    mkdir -p ~/.ssh
                    cat $WORKSPACE/templates/private-key > ~/.ssh/id_rsa
                    cat $WORKSPACE/templates/public-key > ~/.ssh/id_rsa.pub
                    chmod 600 ~/.ssh/id_rsa
                    chmod 644 ~/.ssh/id_rsa.pub
                    eval $(ssh-agent -s)
                    ssh-add ~/.ssh/id_rsa
                    ssh-keyscan github.com >> ~/.ssh/known_hosts
                '''
            }
        }

        stage('Checkout Code') {
            steps {
                script {
                    if (!env.ghprbSourceBranch || !env.ghprbTargetBranch || !env.ghprbActualCommit || !env.ghprbGhRepository) {
                        error "Pull request environment variables are missing. Ensure that the build is triggered by a GitHub pull request."
                    }

                    echo "Pull Request Branch: ${env.ghprbSourceBranch}"
                    echo "Target Branch: ${env.ghprbTargetBranch}"
                    echo "Pull Request Commit: ${env.ghprbActualCommit}"
                    echo "GitHub Repository: ${env.ghprbGhRepository}"

                    def ghRepository = env.ghprbGhRepository
                    def (owner, repo) = ghRepository.tokenize('/')
                    env.GITHUB_OWNER = owner
                    env.GITHUB_REPO = repo

                    withCredentials([string(credentialsId: 'github_token', variable: 'GITHUB_TOKEN')]) {
                        def response = sh(script: """
                            curl -s -H "Authorization: token \$GITHUB_TOKEN" https://api.github.com/repos/${owner}/${repo} | jq -r '.default_branch'
                        """, returnStdout: true).trim()

                        def defaultBranch = response ?: 'master'
                        echo "Default branch for the repository is: ${defaultBranch}"
                        env.DEFAULT_BRANCH = defaultBranch
                    }

                    env.GIT_REPO_URL = "git@github.com:${env.GITHUB_OWNER}/${env.GITHUB_REPO}.git"

                    echo "GITHUB_OWNER: ${env.GITHUB_OWNER}"
                    echo "GITHUB_REPO: ${env.GITHUB_REPO}"
                    echo "GIT_REPO_URL: ${env.GIT_REPO_URL}"

                    checkout([
                        $class: 'GitSCM',
                        branches: [[name: "${env.ghprbActualCommit}"]],
                        doGenerateSubmoduleConfigurations: false,
                        extensions: [
                            [$class: 'CloneOption', depth: 0, noTags: false, reference: '', shallow: false]
                        ],
                        userRemoteConfigs: [[
                            url: "${env.GIT_REPO_URL}",
                            refspec: '+refs/pull/*:refs/remotes/origin/pr/*'
                        ]]
                    ])

                    sh "git fetch origin ${env.DEFAULT_BRANCH}"
                }
            }
        }

        stage('Get Diff for new_qa.tfvars') {
            steps {
                sh '''
                    echo "Generating diff for new_qa.tfvars between ${DEFAULT_BRANCH} and the pull request commit..."
                    git diff origin/${DEFAULT_BRANCH}..HEAD -- new_qa.tfvars > diff.md || true

                    echo "Diff output:"
                    cat diff.md

                    echo "Extracting source changes from the diff..."
                    grep -E '^[-+][[:space:]]*source[[:space:]]*=' diff.md > source_changes.txt || true

                    echo "Content of source_changes.txt:"
                    cat source_changes.txt
                '''
            }
        }

        stage('Check for Source Changes') {
            steps {
                script {
                    def changesDetected = sh(script: 'if [ -s source_changes.txt ]; then echo "true"; else echo "false"; fi', returnStdout: true).trim()
                    if (changesDetected == "true") {
                        echo "Source changes detected"
                        env.CHANGES_DETECTED = "true"
                    } else {
                        echo "No source changes detected"
                        env.CHANGES_DETECTED = "false"
                    }
                }
            }
        }

        stage('Extract and Perform Git Diffs for Changed Modules') {
            when {
                expression { env.CHANGES_DETECTED == 'true' }
            }
            steps {
                script {
                    def sourceChanges = readFile('source_changes.txt').readLines()
                    def sourceMap = [:]

                    def extractSourceUrl = { String text ->
                        def match = text =~ /source\s*=\s*["'](.*?)["']/
                        if (match) {
                            return match[0][1]
                        }
                        return null
                    }

                    def extractRef = { String url ->
                        def refKeyword = '?ref='
                        def refIndex = url.indexOf(refKeyword)
                        if (refIndex != -1) {
                            return url.substring(refIndex + refKeyword.length())
                        }
                        return null
                    }

                    def extractRepo = { String url ->
                        if (url.startsWith('git@github.com:')) {
                            def pathPart = url.substring('git@github.com:'.length())
                            def refIndex = pathPart.indexOf('?ref=')
                            if (refIndex != -1) {
                                pathPart = pathPart.substring(0, refIndex)
                            }
                            if (pathPart.endsWith('.git')) {
                                pathPart = pathPart.substring(0, pathPart.length() - 4)
                            }
                            return pathPart
                        }
                        return null
                    }

                    // Read source modules from the target branch
                    def targetSources = []
                    sh "git show origin/${env.DEFAULT_BRANCH}:new_qa.tfvars > target_new_qa.tfvars || true"
                    if (fileExists('target_new_qa.tfvars')) {
                        def targetContent = readFile('target_new_qa.tfvars')
                        def targetMatches = (targetContent =~ /source\s*=\s*["'](.*?)["']/)
                        targetMatches.each { match ->
                            def sourceUrl = match[1]
                            def sourceKey = sourceUrl.contains('?ref=') ? sourceUrl.substring(0, sourceUrl.indexOf('?ref=')) : sourceUrl
                            targetSources << sourceKey
                        }
                    }

                    // Read source modules from the PR branch
                    def prSources = []
                    if (fileExists('new_qa.tfvars')) {
                        def prContent = readFile('new_qa.tfvars')
                        def prMatches = (prContent =~ /source\s*=\s*["'](.*?)["']/)
                        prMatches.each { match ->
                            def sourceUrl = match[1]
                            def sourceKey = sourceUrl.contains('?ref=') ? sourceUrl.substring(0, sourceUrl.indexOf('?ref=')) : sourceUrl
                            prSources << sourceKey
                        }
                    }

                    sourceChanges.each { line ->
                        line = line.replaceAll(/[\u0000-\u001F]/, '').trim()
                        if (line.length() < 2) {
                            echo "Skipping invalid line: ${line}"
                            return
                        }
                        def sign = line[0]
                        def sourceLine = line.substring(1).trim()

                        def sourceUrl = extractSourceUrl(sourceLine)
                        if (sourceUrl == null) {
                            echo "Failed to extract source URL from line: ${line}"
                            return
                        }

                        def sourceKey = sourceUrl.contains('?ref=') ? sourceUrl.substring(0, sourceUrl.indexOf('?ref=')) : sourceUrl
                        def ref = extractRef(sourceUrl)

                        if (!sourceMap.containsKey(sourceKey)) {
                            sourceMap[sourceKey] = [oldRef: null, newRef: null, isNewModule: false]
                        }

                        if (sign == '-') {
                            sourceMap[sourceKey].oldRef = ref
                        } else if (sign == '+') {
                            sourceMap[sourceKey].newRef = ref
                        }
                    }

                    // Determine new modules
                    prSources.each { sourceKey ->
                        if (!targetSources.contains(sourceKey)) {
                            if (!sourceMap.containsKey(sourceKey)) {
                                sourceMap[sourceKey] = [oldRef: null, newRef: null, isNewModule: true]
                            }
                            sourceMap[sourceKey].isNewModule = true
                        }
                    }

                    // Optional: Debugging - Print the sourceMap
                    // echo "Source Map: ${sourceMap}"

                    sh 'echo "# Git Diffs for Changed Modules" > changelog.md'

                    sourceMap.each { sourceKey, refs ->
                        def oldRef = refs.oldRef
                        def newRef = refs.newRef
                        def isNewModule = refs.isNewModule

                        if (isNewModule) {
                            echo "This is a newly added source: ${sourceKey}; no diff"
                            sh """
                                echo "## New module added: ${sourceKey}" >> changelog.md
                                echo "This is newly added; no diff." >> changelog.md
                            """
                        } else if (oldRef != null || newRef != null) {
                            def repoUrl = sourceKey
                            def repoName = extractRepo(repoUrl)

                            if (repoName == null) {
                                echo "Unsupported or local repository URL: ${repoUrl}. Skipping."
                                return
                            }

                            echo "Processing repository: ${repoName}"
                            def repoDir = "repo_${repoName.replaceAll(/[^\w]/, '_')}"

                            def gitRepoUrl = "git@github.com:${repoName}"
                            if (!repoName.endsWith('.git')) {
                                gitRepoUrl += '.git'
                            }

                            sh """
                                rm -rf ${repoDir}
                                git clone ${gitRepoUrl} ${repoDir}
                            """
                            dir(repoDir) {
                                def moduleDefaultBranch = ''

                                withCredentials([string(credentialsId: 'github_token', variable: 'GITHUB_TOKEN')]) {
                                    moduleDefaultBranch = sh(script: """
                                        curl -s -H "Authorization: token \$GITHUB_TOKEN" https://api.github.com/repos/${repoName} | jq -r '.default_branch'
                                    """, returnStdout: true).trim()

                                    moduleDefaultBranch = moduleDefaultBranch ?: 'master'
                                    echo "Default branch for ${repoName} is: ${moduleDefaultBranch}"
                                }

                                def determineRef = { ref ->
                                    if (ref != null && ref != '') {
                                        return ref
                                    }
                                    echo "Using default ref '${moduleDefaultBranch}' in repository ${repoName}"
                                    return moduleDefaultBranch
                                }

                                oldRef = determineRef(oldRef)
                                newRef = determineRef(newRef)

                                if (oldRef == null || newRef == null) {
                                    echo "Could not determine refs for comparison. Skipping module."
                                    return
                                }

                                sh "git fetch origin ${oldRef}:${oldRef} || git fetch origin tag ${oldRef} || true"
                                sh "git fetch origin ${newRef}:${newRef} || git fetch origin tag ${newRef} || true"

                                def refExists = { ref ->
                                    return sh(
                                        script: "git show-ref --verify --quiet refs/heads/${ref} || git show-ref --verify --quiet refs/tags/${ref}",
                                        returnStatus: true
                                    ) == 0
                                }

                                if (!refExists(oldRef)) {
                                    echo "Old ref '${oldRef}' does not exist in the repository ${repoName}. Skipping."
                                    return
                                }
                                if (!refExists(newRef)) {
                                    echo "New ref '${newRef}' does not exist in the repository ${repoName}. Skipping."
                                    return
                                }

                                def changelogFile = "../changelog_${oldRef}_to_${newRef}.md"
                                sh "git diff ${oldRef} ${newRef} > ${changelogFile}"

                                sh """
                                    echo "## Changes in module from ${oldRef} to ${newRef}" >> ../changelog.md
                                    cat ${changelogFile} >> ../changelog.md
                                """
                            }
                            sh "rm -rf ${repoDir}"
                        } else {
                            echo "No changes detected for source: ${sourceKey}"
                        }

                        if (oldRef != null && newRef == null) {
                            echo "This source has been removed: ${sourceKey}; no diff"
                            sh """
                                echo "## Module removed: ${sourceKey}" >> changelog.md
                                echo "Module has been removed; no diff." >> changelog.md
                            """
                        }
                    }
                }
            }
        }

        stage('Gather comparison results') {
            when {
                expression { env.CHANGES_DETECTED == 'true' }
            }
            steps {
                script {
                    def comments = ''
                    def changelogFiles = ['changelog.md']
                    changelogFiles.each { file ->
                        if (fileExists(file)) {
                            def diffContent = readFile(file).replace('`', '\\`')
                            comments += diffContent + '\n'
                        }
                    }
                    comments = comments.trim()
                    writeFile file: 'combined_comments.md', text: comments
                }
            }
        }
    }

    post {
        always {
            script {
                if (env.ghprbPullId) {
                    def changesDetected = (env.CHANGES_DETECTED == 'true')

                    withCredentials([string(credentialsId: 'github_token', variable: 'GITHUB_TOKEN')]) {
                        def ghRepository = env.ghprbGhRepository
                        def (owner, repo) = ghRepository.tokenize('/')
                        def prNumber = env.ghprbPullId

                        def apiUrl = "https://api.github.com/repos/${owner}/${repo}/issues/${prNumber}/comments"

                        if (changesDetected) {
                            def diffContent = readFile('combined_comments.md').trim()
                            def commentBody = "[BOT COMMENT]\n```diff\n${diffContent}\n```"
                            def requestBody = groovy.json.JsonOutput.toJson([body: commentBody])

                            def existingCommentUrl = sh (
                                script: """
                                    curl -s -H "Authorization: token ${GITHUB_TOKEN}" "${apiUrl}" | jq -r '.[] | select(.body | startswith("[BOT COMMENT]")) | .url'
                                """, 
                                returnStdout: true
                            ).trim()

                            if (existingCommentUrl) {
                                echo "Updating existing comment at: ${existingCommentUrl}"
                                writeFile file: 'update_request.json', text: requestBody
                                sh """
                                    curl -s -X PATCH -H "Authorization: token ${GITHUB_TOKEN}" -H "Content-Type: application/json" -d @update_request.json "${existingCommentUrl}" -o /dev/null
                                """
                                echo "Updated existing comment."
                            } else {
                                echo "No existing comment found. Creating a new comment."
                                writeFile file: 'create_request.json', text: requestBody
                                sh """
                                    curl -s -X POST -H "Authorization: token ${GITHUB_TOKEN}" -H "Content-Type: application/json" -d @create_request.json "${apiUrl}" -o /dev/null
                                """
                                echo "Created new comment."
                            }

                            sh "rm -f update_request.json create_request.json"
                        } else {
                            echo "No source changes detected; no comment will be posted."
                        }
                    }
                } else {
                    echo 'Not a PR build; skipping comment update.'
                }
            }
        }

        failure {
            echo 'Pipeline failed.'
        }
    }
}
