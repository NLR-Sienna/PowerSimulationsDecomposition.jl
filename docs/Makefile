.PHONY: html

html:
	julia --project=. -e 'using Pkg; Pkg.develop(PackageSpec(path="..")); Pkg.instantiate()'
	julia --project=. make.jl
