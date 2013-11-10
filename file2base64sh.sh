#!/bin/bash
#   Copyright 2013 Roy Pfund
#
#   Licensed under the Apache License, Version 2.0 (the  "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable  law  or  agreed  to  in  writing,
#   software distributed under the License is distributed on an  "AS
#   IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,  either
#   express or implied. See the License for  the  specific  language
#   governing permissions and limitations under the License.
#_______________________________________________________________________________
file2base64sh (){ InFile=$1; OutFile=$2 FileName=$3
#file2base64sh "/path/to/somefile" "/path/to/file.sh" "/path/to/someFileName"

	#openssl enc -base64 -A -d <<EOF > '$FileName'
	#base64code for $infile
	#EOF

	echo -e "\nopenssl enc -base64 -A -d <<EOF > '$FileName'" >> $OutFile
	openssl enc -base64 -in $InFile | tr -d '\n' >> $OutFile
	echo -e "\nEOF" >> $OutFile
} #_____________________________________________________________________________

