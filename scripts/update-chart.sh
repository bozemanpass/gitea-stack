#!/bin/bash

set -e

FILE=README.md

CHART_BEGIN=$(grep -n 'CHART_BEGIN' $FILE | head -1 | cut -d':' -f1)
CHART_END=$(grep -n 'CHART_END' $FILE | head -1 | cut -d':' -f1)

head -n $CHART_BEGIN $FILE > $FILE.tmp
echo '```mermaid' >> $FILE.tmp
stack chart --stack stacks/gitea >> $FILE.tmp
echo '```' >> $FILE.tmp
tail -n +$CHART_END $FILE >> $FILE.tmp

mv $FILE.tmp $FILE
