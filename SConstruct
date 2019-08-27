"""Build DAOS"""
import sys
import os
import platform
import subprocess
import locale
import time
import errno
from SCons.Script import BUILD_TARGETS

sys.path.insert(0, os.path.join(Dir('#').abspath, 'utils'))

DESIRED_FLAGS = ['-Wno-gnu-designator',
                 '-Wno-missing-braces',
                 '-Wno-ignored-attributes',
                 '-Wno-gnu-zero-variadic-macro-arguments',
                 '-Wno-tautological-constant-out-of-range-compare',
                 '-Wframe-larger-than=4096']

PP_ONLY_FLAGS = ['-Wno-parentheses-equality', '-Wno-builtin-requires-header',
                 '-Wno-unused-function']

def get_version():

    with open("VERSION", "r") as version_file:
        return version_file.read()

DAOS_VERSION = get_version()

def update_rpm_version(version):
    spec = open("utils/rpms/daos.spec", "r").readlines()
    for line_num, line in enumerate(spec):
        if line.startswith("Version:"):
            spec[line_num] = "Version:       {}\n".format(version)
        if line.startswith("Release:"):
            spec[line_num] = "Release:       1%{?relval}%{?dist}\n"
        if line == "%changelog\n":
            try:
                packager = subprocess.Popen(
                    'rpmdev-packager', stdout=subprocess.PIPE).communicate(
                    )[0].strip().decode('UTF-8')
            except OSError:
                print("You need to have the rpmdev-packager tool (from the "
                      "rpmdevtools RPM on EL7) in order to make releases.\n\n"
                      "Additionally, you should define %packager in "
                      "~/.rpmmacros as such:\n"
                      "%packager	John A. Doe <john.doe@intel.com>"
                      "so that package changelog entries are well defined")
                exit(1)
            date_str = time.strftime('%a %b %d %Y', time.gmtime())
            encoding = locale.getpreferredencoding()
            spec.insert(line_num + 1, "\n")
            spec.insert(line_num + 1,
                        "- Version bump up to {}\n".format(version))
            spec.insert(line_num + 1,
                        u'* {} {} - {}-1\n'.format(date_str,
                                                   packager,
                                                   version))
            break
    open("utils/rpms/daos.spec", "w").writelines(spec)

def is_platform_arm():
    """Detect if platform is ARM"""
    processor = platform.machine()
    arm_list = ["arm", "aarch64", "arm64"]
    if processor.lower() in arm_list:
        return True
    return False

def set_defaults(env):
    """set compiler defaults"""
    AddOption('--preprocess',
              dest='preprocess',
              action='store_true',
              default=False,
              help='Preprocess selected files for profiling')

    env.Append(CCFLAGS=['-g', '-Wshadow', '-Wall', '-Wno-missing-braces',
                        '-fpic', '-D_GNU_SOURCE', '-DD_LOG_V2'])
    env.Append(CCFLAGS=['-O2', '-DDAOS_VERSION=\\"' + DAOS_VERSION + '\\"'])
    env.AppendIfSupported(CCFLAGS=DESIRED_FLAGS)
    if GetOption("preprocess"):
        #could refine this but for now, just assume these warnings are ok
        env.AppendIfSupported(CCFLAGS=PP_ONLY_FLAGS)

def preload_prereqs(prereqs):
    """Preload prereqs specific to platform"""
    prereqs.define('cmocka', libs=['cmocka'], package='libcmocka-devel')
    prereqs.define('readline', libs=['readline', 'history'],
                   package='readline')
    reqs = ['cart', 'argobots', 'pmdk', 'cmocka',
            'uuid', 'crypto', 'fuse', 'protobufc']
    if not is_platform_arm():
        reqs.extend(['spdk', 'isal'])
    prereqs.load_definitions(prebuild=reqs)

def scons():
    if COMMAND_LINE_TARGETS == ['release']:
        org_name = "daos-stack"
        remote_name = "origin"
        try:
            import pygit2
            import github
            import yaml
        except:
            print("You need yaml, pygit2 and pygithub python modules to "
                  "create releases")
            exit(1)

        try:
            token = yaml.safe_load(open(os.path.join(os.path.expanduser("~"),
                                                     ".config", "hub"), 'r')
                )['github.com'][0]['oauth_token']
        except IOError as excpn:
            if excpn.errno == errno.ENOENT:
                print("You need to install hub (from the hub RPM on EL7) to "
                      "and run it at least once to create an authorization "
                      "token in order to create releases")
                exit(1)
            raise

        vars = Variables()
        vars.Add('RELEASE', 'Set to the release version to make', None)
        env = Environment(variables = vars)
        try:
            version = env['RELEASE']
        except KeyError:
            print ("Usage: scons RELEASE=x.y.z release")
            exit(1)

        # create a branch for the PR
        branch = 'create-release-{}'.format(version)
        repo = pygit2.Repository('.git')
        master = repo.lookup_reference(
            'refs/remotes/{}/master'.format(remote_name))
        repo.branches.create(branch, repo[master.target])

        # and check it out
        repo.checkout(repo.lookup_branch(branch))

        with open("VERSION", "w") as version_file:
            version_file.write(version + '\n')

        update_rpm_version(version)

        # now create the commit
        index = repo.index
        index.read()
        author = repo.default_signature
        committer = repo.default_signature
        message = "DAOS-2172 version: bump version to v{}\n".format(version)
        index.add("utils/rpms/daos.spec")
        index.add("VERSION")
        index.write()
        tree = index.write_tree()
        repo.create_commit('HEAD', author, committer, message, tree,
                           [repo.head.target])

        # set up authentication callback
        class MyCallbacks(pygit2.RemoteCallbacks):
            def credentials(self, url, username_from_url, allowed_types):
                if allowed_types & pygit2.credentials.GIT_CREDTYPE_SSH_KEY:
                    if "SSH_AUTH_SOCK" in os.environ:
                        # Use ssh agent for authentication
                        return pygit2.KeypairFromAgent(username_from_url)
                    #else:
                    # need to determine if key is passphrase protected and ask
                    # for the passphrase in order to use this method
                    #    ssh_key = os.path.join(os.path.expanduser("~"),
                    #                           ".ssh", "id_rsa")
                    #    return pygit2.Keypair("git", ssh_key + ".pub",
                    #                          ssh_key, "")
                #elif allowed_types & pygit2.credentials.GIT_CREDTYPE_USERNAME:
                # this is not really useful in the GitHub context
                #    return pygit2.Username("git")
                else:
                    raise Exception("Only unsupported credential types allowed by remote end")

        # and push it
        remote = repo.remotes[remote_name]
        try:
            remote.push(['refs/heads/{}'.format(branch)], callbacks=MyCallbacks())
        except pygit2.GitError:
            print("Error pushing branch.  Does it exist already?")
            exit(1)

        # now create a PR for it
        gh = github.Github(token)
        try:
            org = gh.get_organization(org_name)
            repo = org.get_repo('daos')
        except:
            # maybe not an organization
            repo = gh.get_repo('{}/daos'.format(org_name))
        pr = repo.create_pull(title=message, body="", base="master",
                              head="{}:{}".format(org_name, branch))

        print("Successfully created PR#{} for this version "
              "bump".format(pr.number))

        exit(0)

    """Execute build"""
    if os.path.exists('scons_local'):
        try:
            sys.path.insert(0, os.path.join(Dir('#').abspath, 'scons_local'))
            from prereq_tools import PreReqComponent
            print ('Using scons_local build')
        except ImportError:
            print ('Using traditional build')

    env = Environment(TOOLS=['extra', 'default'])

    if os.path.exists("daos_m.conf"):
        os.rename("daos_m.conf", "daos.conf")

    opts_file = os.path.join(Dir('#').abspath, 'daos.conf')
    opts = Variables(opts_file)

    commits_file = os.path.join(Dir('#').abspath, 'utils/build.config')
    if not os.path.exists(commits_file):
        commits_file = None

    prereqs = PreReqComponent(env, opts, commits_file)
    preload_prereqs(prereqs)
    opts.Save(opts_file, env)

    env.Alias('install', '$PREFIX')
    platform_arm = is_platform_arm()
    Export('DAOS_VERSION', 'env', 'prereqs', 'platform_arm')

    if env['PLATFORM'] == 'darwin':
        # generate .so on OSX instead of .dylib
        env.Replace(SHLIBSUFFIX='.so')

    set_defaults(env)

    # generate targets in specific build dir to avoid polluting the source code
    VariantDir('build', '.', duplicate=0)
    SConscript('build/src/SConscript')

    buildinfo = prereqs.get_build_info()
    buildinfo.gen_script('.build_vars.sh')
    buildinfo.save('.build_vars.json')
    env.InstallAs("$PREFIX/TESTING/.build_vars.sh", ".build_vars.sh")
    env.InstallAs("$PREFIX/TESTING/.build_vars.json", ".build_vars.json")
    env.InstallAs("$PREFIX/lib/daos/VERSION", "VERSION")

    # install the configuration files
    SConscript('utils/config/SConscript')

    # install certificate generation files
    SConscript('utils/certs/SConscript')

    Default('build')
    Depends('install', 'build')

    try:
        #if using SCons 2.4+, provide a more complete help
        Help(opts.GenerateHelpText(env), append=True)
    except TypeError:
        Help(opts.GenerateHelpText(env))

if __name__ == "SCons.Script":
    scons()
