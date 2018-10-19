#!/usr/bin/env groovy

void docker_agent(name) {
    dockerfile {
        filename name
        dir 'utils/docker'
        label 'docker_runner'
        additionalBuildArgs '--build-arg NOBUILD=1 --build-arg UID=$(id -u) --build-arg DONT_USE_RPMS=false  --build-arg HTTP_PROXY=\\"${HTTP_PROXY}\\" --build-arg http_proxy=\\"${HTTP_PROXY}\\" --build-arg HTTPS_PROXY=\\"${HTTPS_PROXY}\\" --build-arg https_proxy=\\"${HTTPS_PROXY}\\"'
    }
}

pipeline {
    agent none

    environment {
        SHELL = '/bin/bash'
        BAHTTPS_PROXY = "${env.HTTP_PROXY ? '--build-arg HTTP_PROXY="' + env.HTTP_PROXY + '" --build-arg http_proxy="' + env.HTTP_PROXY + '"' : ''}"
        BAHTTP_PROXY = "${env.HTTP_PROXY ? '--build-arg HTTPS_PROXY="' + env.HTTPS_PROXY + '" --build-arg https_proxy="' + env.HTTPS_PROXY + '"' : ''}"
        DBA1 = '--build-arg NOBUILD=1'
        DBA2 = ' --build-arg UID=$(id -u)'
        DBA3 = ' --build-arg DONT_USE_RPMS=false'
        DBA4 = ' --build-arg HTTP_PROXY=\"\${HTTP_PROXY}\"'
        DBA5 = ' --build-arg HTTPS_PROXY=\"\${HTTPS_PROXY}\"'
        DBA2A = ' --build-arg UID=\$(id -u)'

        DEF_BUILD_ARGS = "${DBA1}${DBA2}${DBA3}${DBA4}${DBA5}"
        DEF_BUILD_ARGSA = "${DBA1}${DBA2A}${DBA3}${DBA4}${DBA5}"
        UID=sh(script: "id -u", returnStdout: true)
        BUILDARGS = "--build-arg NOBUILD=1 --build-arg UID=$env.UID --build-arg DONT_USE_RPMS=false $env.BAHTTP_PROXY $env.BAHTTPS_PROXY"
    }

    // triggers {
        // Jenkins instances behind firewalls can't get webhooks
        // sadly, this doesn't seem to work
        // pollSCM('* * * * *')
        // See if cron works since pollSCM above isn't
        // cron('H 22 * * *')
    // }

    options {
        // preserve stashes so that jobs can be started at the test stage
        preserveStashes(buildCount: 5)
    }

    stages {
        stage('dump-env') {
            agent { label 'docker_runner' }
            steps {
                sh 'export'
                sh 'echo "${DEF_BUILD_ARGSA}"'
                sh 'echo "${DBA4}${DBA5}"'
            }
        }
        stage('Pre-build') {
            parallel {
                stage('check_modules.sh') {
                    agent {
                        dockerfile {
                            filename 'Dockerfile.centos:7'
                            dir 'utils/docker'
                            label 'docker_runner'
                            additionalBuildArgs '$BUILDARGS'
                        }
                    }
                    steps {
                        githubNotify description: 'checkmodules.sh',  context: 'checkmodules.sh', status: 'PENDING'
                        sh '''pushd scons_local
                              git fetch https://review.hpdd.intel.com/coral/scons_local refs/changes/13/33013/11
                              popd
                              git submodule update --init --recursive
                              utils/check_modules.sh'''
                    }
                    post {
                        always {
                            archiveArtifacts artifacts: 'pylint.log', allowEmptyArchive: true
                        }
                        success {
                            githubNotify description: 'checkmodules.sh',  context: 'checkmodules.sh', status: 'SUCCESS'
                        }
                        unstable {
                            githubNotify description: 'checkmodules.sh',  context: 'checkmodules.sh', status: 'FAILURE'
                        }
                    }
                }
            }
        }
        stage('Build') {
            parallel {
                stage('Build on CentOS 7') {
                    agent {
                        dockerfile {
                            filename 'Dockerfile.centos:7'
                            dir 'utils/docker'
                            label 'docker_runner'
                            additionalBuildArgs '$BUILDARGS'
                        }
                    } // agent
                    steps {
                        githubNotify description: 'CentOS 7 Build',  context: 'build/centos7', status: 'PENDING'
                        checkout scm
                        sh '''git submodule update --init --recursive
                              scons -c
                              # scons -c is not perfect so get out the big hammer
                              rm -rf _build.external install build
                              pushd scons_local
                              git fetch https://review.hpdd.intel.com/coral/scons_local refs/changes/13/33013/11
                              popd
                              utils/fetch_go_packages.sh -i .
                              SCONS_ARGS="--update-prereq=all --build-deps=yes USE_INSTALLED=all install"
                              if ! scons $SCONS_ARGS; then
                                  if ! scons --config=force $SCONS_ARGS; then
                                      rc=\${PIPESTATUS[0]}
                                      cat config.log || true
                                      exit \$rc
                                  fi
                              fi'''
                        stash name: 'CentOS-install', includes: 'install/**'
                        stash name: 'CentOS-build-vars', includes: '.build_vars.*'
                        stash name: 'CentOS-tests', includes: 'build/src/rdb/raft/src/tests_main, build/src/common/tests/btree_direct, build/src/common/tests/btree, src/common/tests/btree.sh, build/src/common/tests/sched, build/src/client/api/tests/eq_tests, src/vos/tests/evt_ctl.sh, build/src/vos/vea/tests/vea_ut, src/rdb/raft_tests/raft_tests.py'
                    } // steps
                    post {
                        success {
                            githubNotify description: 'CentOS 7 Build',  context: 'build/centos7', status: 'SUCCESS'
                        }
                        unstable {
                            githubNotify description: 'CentOS 7 Build',  context: 'build/centos7', status: 'FAILURE'
                        }
                    } // post
                } // stage
                stage('Build on Ubuntu 18.04') {
                    agent {
                        dockerfile {
                            filename 'Dockerfile.ubuntu:18.04'
                            dir 'utils/docker'
                            label 'docker_runner'
                            additionalBuildArgs '$BUILDARGS'
                        }
                    } // agent
                    steps {
                        githubNotify description: 'Ubuntu 18 Build',  context: 'build/ubuntu18', status: 'PENDING'
                        checkout scm
                        sh '''git submodule update --init --recursive
                              scons -c
                              # scons -c is not perfect so get out the big hammer
                              rm -rf _build.external install build
                              utils/fetch_go_packages.sh -i .
                              SCONS_ARGS="--update-prereq=all --build-deps=yes USE_INSTALLED=all install"
                              if ! scons $SCONS_ARGS; then
                                  if ! scons --config=force $SCONS_ARGS; then
                                      rc=\${PIPESTATUS[0]}
                                      cat config.log || true
                                      exit \$rc
                                  fi
                              fi'''
                    } // steps
                    post {
                        success {
                            githubNotify description: 'Ubuntu 18 Build',  context: 'build/ubuntu18', status: 'SUCCESS'
                        }
                        unstable {
                            githubNotify description: 'Ubuntu 18 Build',  context: 'build/ubuntu18', status: 'FAILURE'
                        }
                    } // post
                } // stage('Build on Ubuntu 18.04')
            } // parallel
        } // stage('Build')
/*        stage('Test') {
            parallel {
                stage('Functional quick') {
                    agent {
                        label 'cluster_provisioner'
                    }
                    steps {
                        githubNotify description: 'Functional quick',  context: 'test/functional_quick', status: 'PENDING'
                        dir('install') {
                            deleteDir()
                        }
                        unstash 'CentOS-install'
                        unstash 'CentOS-build-vars'
                        sh '''bash ftest.sh quick
                              rm -rf src/tests/ftest/avocado/job-results/html/
                              mv install/tmp/daos.log daos-Functional-quick.log'''
                    }
                    post {
                        always {
                            archiveArtifacts artifacts: 'daos-Functional-quick.log, src/tests/ftest/avocado/job-results/**'
                            // replaced * below with a # for commenting out the block
                            junit 'src/tests/ftest/avocado/job-results/#/results.xml'
                        }
                        success {
                            githubNotify description: 'Functional quick',  context: 'test/functional_quick', status: 'SUCCESS'
                        }
                        unstable {
                            githubNotify description: 'Functional quick',  context: 'test/functional_quick', status: 'FAILURE'
                        }
                    }
                }
                stage('run_test.sh') {
                    agent {
                        label 'single'
                    }
                    steps {
                        githubNotify description: 'run_test.sh',  context: 'test/run_test.sh', status: 'PENDING'
                        dir('install') {
                            deleteDir()
                        }
                        unstash 'CentOS-tests'
                        unstash 'CentOS-install'
                        unstash 'CentOS-build-vars'
                        sh '''HOSTPREFIX=wolf-53 bash -x utils/run_test.sh --init
                              mv /tmp/daos.log daos-run_test.sh.log'''
                    }
                    post {
                        always {
                            archiveArtifacts artifacts: 'daos-run_test.sh.log'
                        }
                        success {
                            githubNotify description: 'run_test.sh',  context: 'test/run_test.sh', status: 'SUCCESS'
                        }
                        unstable {
                            githubNotify description: 'run_test.sh',  context: 'test/run_test.sh', status: 'FAILURE'
                        }
                    }
                }
                stage('DaosTestMulti All') {
                    agent {
                        label 'cluster_provisioner'
                    }
                    steps {
                        githubNotify description: 'DaosTestMulti All',  context: 'test/daostestmulti_all', status: 'PENDING'
                        dir('install') {
                            deleteDir()
                        }
                        unstash 'CentOS-install'
                        sh '''trap 'mv daos{,-DaosTestMulti-All}.log
                                    [ -f results.xml ] && mv -f results{,-DaosTestMulti-All}.xml' EXIT
                              bash DaosTestMulti.sh || true'''
                    }
                    post {
                        always {
                            archiveArtifacts artifacts: 'daos-DaosTestMulti-All.log, results-DaosTestMulti-All.xml'
                            junit allowEmptyResults: true, testResults: 'results-DaosTestMulti-All.xml'
                        }
                        success {
                            githubNotify description: 'DaosTestMulti All',  context: 'test/daostestmulti_all', status: 'SUCCESS'
                        }
                        unstable {
                            githubNotify description: 'DaosTestMulti All',  context: 'test/daostestmulti_all', status: 'FAILURE'
                        }
                    }
                }
                stage('DaosTestMulti Degraded') {
                    agent {
                        label 'cluster_provisioner'
                    }
                    steps {
                        githubNotify description: 'DaosTestMulti Degraded',  context: 'test/daostestmulti_degraded', status: 'PENDING'
                        dir('install') {
                            deleteDir()
                        }
                        unstash 'CentOS-install'
                        sh '''trap 'mv daos{,-DaosTestMulti-Degraded}.log
                                    [ -f results.xml ] && mv -f results{,-DaosTestMulti-Degraded}.xml' EXIT
                              bash DaosTestMulti.sh -d || true'''
                    }
                    post {
                        always {
                            archiveArtifacts artifacts: 'daos-DaosTestMulti-Degraded.log, results-DaosTestMulti-Degraded.xml'
                            junit allowEmptyResults: true, testResults: 'results-DaosTestMulti-Degraded.xml'
                        }
                        success {
                            githubNotify description: 'DaosTestMulti Degraded',  context: 'test/daostestmulti_degraded', status: 'SUCCESS'
                        }
                        unstable {
                            githubNotify description: 'DaosTestMulti Degraded',  context: 'test/daostestmulti_degraded', status: 'FAILURE'
                        }
                    }
                }
                stage('DaosTestMulti Rebuild') {
                    agent {
                        label 'cluster_provisioner'
                    }
                    steps {
                        githubNotify description: 'DaosTestMulti Rebuild',  context: 'test/daostestmulti_rebuild', status: 'PENDING'
                        dir('install') {
                            deleteDir()
                        }
                        unstash 'CentOS-install'
                        sh '''trap 'mv daos{,-DaosTestMulti-Rebuild}.log
                                    [ -f results.xml ] && mv -f results{,-DaosTestMulti-Rebuild}.xml' EXIT
                              bash DaosTestMulti.sh -r || true'''
                    }
                    post {
                        always {
                            archiveArtifacts artifacts: 'daos-DaosTestMulti-Rebuild.log, results-DaosTestMulti-Rebuild.xml'
                            junit allowEmptyResults: true, testResults: 'results-DaosTestMulti-Rebuild.xml'
                        }
                        success {
                            githubNotify description: 'DaosTestMulti Rebuild',  context: 'test/daostestmulti_rebuild', status: 'SUCCESS'
                        }
                        unstable {
                            githubNotify description: 'DaosTestMulti Rebuild',  context: 'test/daostestmulti_rebuild', status: 'FAILURE'
                        }
                    }
                }
            } // parallel
        } */ // stage('Test')
    } // stages
} // pipeline
