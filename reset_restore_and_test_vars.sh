#!/bin/bash

echo "Removing all dataset cache markers ..."
find ./datasets -regex '.*vars.*restore_result$'
find ./datasets -regex '.*vars.*restore_result$' -delete
echo "Done"

echo "Removing all test execution cache markers ..."
find ./tests -regex '.*vars.*_result$'
find ./tests -regex '.*vars.*_result$' -delete
echo "Done"