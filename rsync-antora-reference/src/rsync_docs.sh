#!/bin/bash

__rsync_docs_usage() {
  echo "usage: rsync_docs.sh [OPTION]...

   --ssh-host=SSH_HOST              the ssh host in the format USER@HOST to connect to ssh
   --ssh-private-key-path=KEY_PATH  the path to the private key used to connect to ssh
   --ssh-host-path=HOST_PATH        the path of the ssh server to sync the documentation to
   --dry-run                        signals that rsync should be in dry run mode
   --local-path=PATH                the local directory path to sync to the server
   --build-ref-name=REF_NAME        the build_ref_name
"
}

__rsync_docs_usage_error() {
  echo "Error: $1" >&2
  __rsync_docs_usage
  exit 1
}

__rsync_docs() {
  local ssh_host ssh_host_path local_path ssh_private_key_path build_ref_name
  local dry_run="false"
  valid_args=$(getopt --options '' --long ssh-host:,ssh-host-path:,dry-run,local-path:,ssh-private-key-path:,build-ref-name: -- "$@")
  if [[ $? -ne 0 ]]; then
    __rsync_docs_usage
    exit 1;
  fi

  eval set -- "$valid_args"

  while [ : ]; do
    case "$1" in
      --ssh-host)
          ssh_host="$2"
          shift 2
          ;;
      --ssh-host-path)
          ssh_host_path="$2"
          shift 2
          ;;
      --local-path)
          local_path="$2"
          shift 2
          ;;
      --ssh-private-key-path)
          ssh_private_key_path="$2"
          shift 2
          ;;
      --build-ref-name)
          build_ref_name="$2"
          shift 2
          ;;
      --dry-run)
          dry_run=true
          shift
          ;;
       --) shift;
          break
          ;;
      *)
        __rsync_docs_usage_error "Invalid argument $1 $2"
        ;;
    esac
  done

  if [ -z "$ssh_host" ]; then
    __rsync_docs_usage_error "Missing option '--ssh-host'"
  fi
  if [ -z "$ssh_host_path" ]; then
    __rsync_docs_usage_error "Missing option '--ssh-host-path'"
  fi
  if [ -z "$local_path" ]; then
    __rsync_docs_usage_error "Missing option '--local-path'"
  fi
  if [ -z "$ssh_private_key_path" ]; then
    __rsync_docs_usage_error "Missing option '--ssh-private-key-path'"
  fi

  local rsync_opts='-avz --delete '
  if [ "$dry_run" != "false" ]; then
    rsync_opts="$rsync_opts --dry-run "
  fi
  if [ -f "$local_path/.htaccess" ]; then
    rsync_opts="$rsync_opts --include /.htaccess "
  fi
  if [ -d "$local_path/.cache" ]; then
    rsync_opts="$rsync_opts$(find $local_path/.cache -printf ' --include /.cache/%P')"
  fi
  rsync_opts="$rsync_opts --exclude /.github-repository --exclude /.cache --exclude /.cache/* "
  if [ -n "$build_ref_name" ]; then
    rsync_opts="-c $rsync_opts$(find $local_path -mindepth 1 -maxdepth 1 \! -name 404.html \! -name '.*' -type f -printf ' --include /%P')"
    rsync_opts="$rsync_opts$(find $local_path -mindepth 1 -maxdepth 1 -type d \! -name _ -printf ' --include /%P --include /%P/**') --exclude **"
  fi
  (
    # Disable filename expansion (globbing)
    # https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html
    set -f
    rsync $rsync_opts -e "ssh -i $ssh_private_key_path" $local_path/ "$ssh_host:$ssh_host_path"
  )
}


__rsync_docs "$@"
