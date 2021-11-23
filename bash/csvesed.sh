#!/bin/bash
elab=$1

sed -i '' -e "s#\[\'#\"\{\'#g" $elab
sed -i '' -e "s#\'\]#\'\}\"#g" $elab
sed -i '' -e "s#\'\([A-Za-z]*\)\'#\1#g" $elab
