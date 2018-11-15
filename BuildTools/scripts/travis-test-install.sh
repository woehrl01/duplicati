#!/bin/bash

nuget install NUnit.Runners -Version 3.5.0 -OutputDirectory testrunner
sudo pip install selenium
sudo pip install --upgrade urllib3
