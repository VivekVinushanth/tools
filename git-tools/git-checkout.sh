#!/bin/bash
# run this from your workspace, which contains all your Git repos
# usage : ./git-checkout <product_version> <force>
# usage : ./git-checkout 5.2.0 y

wrk_dir=$(pwd)
mkdir -p $wrk_dir'/artefacts'

REPO_FILE=$wrk_dir'/artefacts/repo-versions'

git config --global credential.helper cache

if [ ! -f "$REPO_FILE" ]; then
    printf "WARN : repo-versions file is missing , hence downloading from git. \nif you wish to update the repo-versions use the script from here https://git.io/JOTSj \n"
    curl -s https://raw.githubusercontent.com/dmxunlimit/tools/master/git-tools/artefacts/repo-versions -o $REPO_FILE
fi

if [ -z $1 ]; then
    read -p 'Default checkout is MASTER or Enter the Identity Server version to checkout [5.2.0]: ' branch_version
else
    branch_version=$1
fi

force=$(echo "$2" | awk '{print tolower($0)}')

if [ -z $force ]; then
    read -p 'Force checkout [no]: ' force
    if [ "$force" == "yes" ] || [ "$force" == "y" ]; then
        printf "\nWRAN : Force checkout , local changes will destroy !!\n"
        force="-f"
    else
        force=""
    fi
elif [ $force == "yes" ] || [ $force == "y" ]; then
    printf "\nWRAN : Force checkout , local changes will destroy !!\n"
    force="-f"
else
    force=""
fi

gitCheckout() {
    printf "Remote: $NEW_REMOTE"
    printf "\n"
    git remote set-url origin "$NEW_REMOTE"
    if [ -z $tag ]; then
        echo "# Checking out branch "$branch" for" $dirname
        git checkout $branch $force
        git pull
    else
        echo "# Checking out tag "$branch" for" $dirname
        git checkout $branch $force -q
    fi
}

getBranch() {
    dirname=$1
    dirname="${dirname:2}"
    branch=''
    branch_version=$2

    if [ "$branch_version" != "master" ] && [ ! -z $branch_version ]; then
        version='wso2is-'$branch_version
        tag=''
        version=$(echo $version | sed 's/\./\-/g')
        key=$dirname"-"$version

        key=$(grep "^$key" $REPO_FILE)

        if [ ! -z "$key" ]; then

            value=$(echo $key | cut -d "=" -f2 | sed s/"'"/" "/g)
            key=$(echo $key | cut -d "=" -f1)

            printf "\n"
            printf "\nRepo Directory :$i\n"
            echo "Repo Key:"$key
            echo "Repo Version:"$value

            if [ ! -z "$value" ]; then
                branch=$value
                support_brach=$(git branch -r | grep $branch | grep 'support' | grep -Ev 'release|security|full|revert' | head -1)
                if [ -z "$support_brach" ]; then
                    gen_branch=$(git branch -r | grep $branch | grep -Ev 'HEAD|release|security|full|revert' | head -1)

                    if [ -z "$gen_branch" ]; then
                        echo "No branch found ,hence checking tag :"$branch
                        tag=$(git tag | grep $branch | head -1)
                        echo "TAG Version :"$tag
                        if [ -z "$tag" ]; then
                            echo $key >>$wrk_dir'/artefacts/missing-repos'
                        fi
                        branch=$tag
                    else
                        branch=$gen_branch
                    fi

                else
                    branch=$support_brach
                fi

                branch=$(echo $branch | sed -e 's/origin\///g')
            fi

            if [ -z "$branch" ]; then
                branch='master'
            fi
            gitCheckout
        fi
    else

        branch='master'
        printf "\n"
        gitCheckout
    fi

}

echo "$branch"

printf "Updating remotes for all repositories...\n"
for i in $(find . -mindepth 1 -maxdepth 1 -type d); do
    if [ $i != "./.idea" ] && [ $i != "./artefacts" ]; then
        cd "$i"
        THIS_REMOTES="$(git remote -v)"
        arr=($THIS_REMOTES)
        OLD_REMOTE="${arr[1]}"
        NEW_REMOTE="${OLD_REMOTE/git.old.net/git.new.org}"
        getBranch $i $branch_version
        cd $wrk_dir
    fi
done

printf "\nCompleted!\n"
