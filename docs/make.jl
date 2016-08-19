using Documenter, Couchzilla
 
makedocs(modules=[Couchzilla], doctest=true)
 
deploydocs(
	deps = Deps.pip("mkdocs"),
    repo = "github.com/xpqz/couchzilla.git",
    julia  = "0.4.6",
    osname = "osx")