# `docker build` guard: refuse a local build context with no .dockerignore, since
# the whole directory (.env, keys, .git) goes to the daemon and `COPY . .` bakes
# it into a layer. Fix with `dockerignore-init`; bypass once with
# DOCKER_ALLOW_NO_IGNORE=1 or `command docker build …`.
# Covers `docker build`, `docker buildx build`, `docker image build` — not
# `compose build` or `buildx bake`, whose contexts live in YAML/HCL.

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

    local ctx="${@[-1]}" file=""
    while (( $# > 1 )); do
        case "$1" in
            -f|--file) file="$2"; shift 2; continue ;;
            --file=*)  file="${1#--file=}" ;;
            -f?*)      file="${1#-f}" ;;
        esac
        shift
    done

    # stdin, git/http URLs and tarballs carry their own context.
    if [[ $ctx == - || $ctx == *://* || $ctx == git@* || ! -d $ctx ]]; then
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
