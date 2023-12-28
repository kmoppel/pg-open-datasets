#!/bin/bash

echo "Removing all dataset cache markers ..."
find ./datasets -regex '.*vars.*_result$'
find ./datasets -regex '.*vars.*_result$' -delete
echo "Done"

echo "Removing all test execution cache markers ..."
find ./tests -regex '.*vars.*_result$'
find ./tests -regex '.*vars.*_result$' -delete
echo "Done"