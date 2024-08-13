#!/bin/bash

# Setup the XML
FILESXML="<xml build-time=\"$(date +%s)\">"
REPOSXML="<xml build-time=\"$(date +%s)\">"
# Create some empty arrays
# COMMITS: Array filled with commit hashes corrosponding to index*2-1 in the COMMITFILES array file
COMMITS=()
# COMMITFILES: Array filled with commit files and branches, following ("file", "branch") using 2 items as 1
COMMITFILES=()
# Some unicode values for splitting
_NUL="␀"
_SOH="␁"
_STX="␂"
# Loop over all the users in the repos directory
for user in ../repos/*; do
  # If the user is * or starts with ! then it meants to not include it in the XML
  # Or if "folder" is actually a file that starts with README
  # This can be applied for date, and file aswell.
  if [[ "$user" =~ (\!.*)|(\*)|(README.*) ]]; then
    echo > /dev/null;
  else
    # Looping over all the repos in the users folder
    for repo in "$user"/*; do
      # Getting the repos github url based on the username and repo name
      REPO="$(basename "$user")/$(basename $repo)"
      XML="\n  <repo url=\"https://github.com/$REPO\">"
      # Adding the repo to the repos XML
      REPOSXML+="\n  <repo url=\"https://github.com/$REPO\"></repo>"
      # Looping over all the dates in the user/repo folder
      for date in "$repo"/*; do
        DATE=$(basename "$date")
        if [[ "$DATE" =~ (\!.*)|(\*)|(README.*) ]]; then
          echo > /dev/null;
        else
          XML+="\n    <date day=\"$DATE\">"
          # Looping over all the files in the date
          for file in "$date"/*; do
            # Getting the full file name
            FILE=$(basename "$file")
            if [[ "$FILE" =~ (\!.*)|(\*)|(README.*) ]]; then
              echo > /dev/null;
            else
              # Extracting the actual file name, branch and commit hash from the extended format.
              IFS="$_SOH" read -a tmp <<< "$FILE"
              FILENAME=${tmp[-2]:0:-1}
              BRANCH=${tmp[-1]%%$_STX*}
              tmp=${tmp[-1]:${#BRANCH}+1}
              COMMIT=${tmp%%"."*}
              FILENAME="$FILENAME${tmp:40}"
              FILENAME=${FILENAME//$_NUL/"/"}
              # Remove and precending backslashes
              tmp=${FILENAME:0:1}
              if [ $tmp = "/" ]; then
                FILENAME=${FILENAME:1}
              fi
              # Check if we already have this commit
              tmp=$(echo ${COMMITS[@]} | grep -ow "$COMMIT" | wc -w)
              if [ $tmp -lt 1 ]; then
                # If not add it to the commits array and add 2 items to the commit files array
                COMMITS+=("$COMMIT")
                COMMITFILES+=("" "")
                # Find the index of the commit in the commits array
                tmp=$(echo ${COMMITS[@]} | grep -w "$COMMIT" | wc -w)
                # Adding a temporary replacer value to add the generated commit XML later
                XML+="\n__$tmp"
              else
                # Find the index of the commit in the commits array
                tmp=$(echo ${COMMITS[@]} | grep -w "$COMMIT" | wc -w)
              fi
              # Cleanup unused variables
              unset COMMIT
              unset EXTENSION
              # shell script does not support nested arrays | example: (("im a nested array"))
              # So to replicate it we add a "." for a seperator and base64 encode the string and add that
              # using "." to split the base64 then decode all the values to get the subarray
              # base64 is used because it is widly supported and easy to use, and also does not contain any "."'s
              # so we can use it in our nested array implementation
              # Adding the base64 for the real file name
              COMMITFILES[tmp*2-1]+=".$(base64 <<< "$FILENAME")"
              # Cleanup unused variables
              unset FILENAME
              # Adding the base64 for the branch
              COMMITFILES[tmp*2]+=".$(base64 <<< "$BRANCH")"
              # Cleanup unused variables
              unset BRANCH
              unset tmp
            fi
            # Cleanup unused variables
            unset file
            unset FILE
          done
          XML+="\n    </date>"
        fi
        # Cleanup unused variables
        unset date
        unset DATE
      done
      # Cleanup unused variables
      unset repo
      unset REPO
      # Adding the XML to the full XML
      XML+="\n  </repo>"
      FILESXML+="$XML"
      unset XML
    done
  fi
  # Cleanup unused variables
  unset user
  unset USER
done
# Cleanup unused variables
unset XML
unset _NUL
unset _SOH
unset _STX
# Adding the closing XML to the repos and files XML
FILESXML+="\n</xml>"
REPOSXML+="\n</xml>"
# Looping over all the commits to generate the final files xml
# Starting our counter at 1 to mitigate multiplication of 0 issues
tmp2=1
for COMMIT in "${COMMITS[@]}"; do
  # Extracting the file name and base64 arrays based on the commit
  tmp3="${COMMITFILES[tmp2*2]}"
  tmp="${COMMITFILES[tmp2*2-1]}"
  # Converting the values back into an array with the seperator "."
  IFS=. read -a tmp <<< "$tmp"
  IFS=. read -a tmp3 <<< "$tmp3"
  tmp3=("${tmp3[@]:1}")
  tmp=(${tmp[@]:1})
  # Making the commit XML
  XML="      <commit hash=\"$COMMIT\">"
  # Cleanup unused variables
  unset COMMIT
  # Looping over all the filenames in the split files array
  tmp4=0
  for FILENAME in "${tmp[@]}"; do
    # Adding the XML for the file, we decode the filename and branch as they are still encoded in base64
    XML+="\n        <file name=\"$(base64 -d <<< $FILENAME)\" branch=\"$(base64 -d <<< "${tmp3[$tmp4]}")\" />"
    # Cleanup unused variables and increment the index so we know where to what item to get the next branch on
    unset FILENAME
    tmp4=$(($tmp4+1))
  done
  # Cleaning up unused variables
  unset tmp4
  unset tmp3
  # Finishing off the XML
  XML="$XML\n      </commit>"
  # Finding the replacer value in files XML to update it with our commit XML
  # And then replacing it
  tmp="__$(($tmp2))"
  FILESXML="${FILESXML/$tmp/"$XML"}"
  # Cleaning up unused variables and incrementing the counter
  unset XML
  unset tmp
  tmp2=$(($tmp2+1))
done
# Cleaning up unused variables
unset tmp2
unset COMMITS
unset COMMITFILES
# Writing the files and repos xml to the build/meta and doing our final cleanup
printf "$FILESXML" > ../build/meta/archive.xml
unset FILESXML
printf "$REPOSXML" > ../build/meta/repos.xml
unset REPOSXML
