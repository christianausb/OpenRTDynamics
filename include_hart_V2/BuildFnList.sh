#!/bin/sh

# find all functions starting with rt_

nm module_src/*.o | grep rt_ | awk '{print $3}' | awk '/^rt/ { print $1 }' > FnList
