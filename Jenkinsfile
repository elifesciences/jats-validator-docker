elifePipeline {
    def commit
    DockerImage image

    node('containers-jenkins-plugin') {
        stage 'Checkout', {
            checkout scm
            commit = elifeGitRevision()
        }

        stage 'Build images', {
            dockerBuild('jats-validator', commit)
        }

//        stage 'Project tests', {
//            dockerComposeProjectTests('digests', commit, ['/srv/digests/build/*.xml'])
//           dockerComposeSmokeTests(commit, [
//                'scripts': [
//                    'wsgi': './smoke_tests_wsgi.sh',
//                ],
//            ])
//        }

        elifeMainlineOnly {
            stage 'Push image', {
                image = DockerImage.elifesciences(this, 'jats-validator', commit)
                image.push()
                image.tag('latest').push()
            }
        }
    }
}