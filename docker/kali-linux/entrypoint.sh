#!/bin/bash

# Start SSH
service ssh start

# Keep container alive
tail -f /dev/null