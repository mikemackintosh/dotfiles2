# `docker build` guard: refuse a local build context with no .dockerignore, since
# the whole directory (.env, keys, .git) goes to the daemon and `COPY . .` bakes
# it into a layer. Fix with `dockerignore-init`; bypass once with
# DOCKER_ALLOW_NO_IGNORE=1 or `command docker build …`.
# Covers `docker build`, `docker buildx build`, `docker image build` — not
# `compose build` or `buildx bake`, whose contexts live in YAML/HCL.
# Guards your interactive shell only; scripts call the real docker binary.

docker() {
    local -a rest=("$@")
    case "$1" in
        build) shift 1 ;;
        buildx|image) [[ $2 == build ]] || { command docker "$@"; return; }; shift 2 ;;
        *) command docker "$@"; return ;;
    esac
    if [[ -n ${DOCKER_ALLOW_NO_IGNORE:-} ]] || (( $# == 0 )); then
        command docker "${rest[@]}"; return
    fi

    # Find the context by consuming flags, so it's located regardless of
    # position: `docker build -t x .` and `docker build . -t x` both work.
    # The old "last arg" heuristic let `docker build . -t x` slip past.
    local file="" a
    local -a positionals
    while (( $# )); do
        a=$1
        if   [[ $a == --file=* ]]; then file=${a#--file=}; shift; continue
        elif [[ $a == -f?*     ]]; then file=${a#-f};      shift; continue
        elif [[ $a == -f || $a == --file ]]; then file=$2; shift 2; continue
        fi
        case $a in
            # value-taking flags consume the next arg (the `--flag=value`
            # form falls through to the self-contained case below)
            -t|--tag|--build-arg|--label|--target|--platform|--network|\
            --cache-from|--cache-to|-o|--output|--secret|--ssh|--add-host|\
            --allow|--attest|--build-context|--annotation|--iidfile|--call|\
            --metadata-file|--no-cache-filter|--progress|--provenance|--sbom|\
            --shm-size|--ulimit|--cgroup-parent|-m|--memory)
                shift 2; continue ;;
            --*=*|-*) shift; continue ;;   # self-contained long flag, or boolean
            *) positionals+=$a; shift ;;
        esac
    done

    # docker build takes exactly one positional: the context.
    local ctx=${positionals[-1]:-}
    # No context, stdin, git/http URLs and tarballs carry their own context.
    if [[ -z $ctx || $ctx == - || $ctx == *://* || $ctx == git@* || ! -d $ctx ]]; then
        command docker "${rest[@]}"; return
    fi
    [[ -n $file && $file != /* ]] && file="$PWD/$file"
    if [[ ! -f $ctx/.dockerignore && ( -z $file || ! -f $file.dockerignore ) ]]; then
        print -u2 "docker: refusing to build: no .dockerignore in ${ctx:a} — the whole dir would be sent."
        print -u2 "        dockerignore-init ${(q)ctx}   # or DOCKER_ALLOW_NO_IGNORE=1 docker …"
        return 1
    fi
    command docker "${rest[@]}"
}
