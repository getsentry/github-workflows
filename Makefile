.PHONY: test
.SILENT: test
.ONESHELL:

test: tests/*.ps1
	@set -e
	for file in $^ ; do
		echo "Running " $${file} ;
		pwsh $${file} ;
	done
