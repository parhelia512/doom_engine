out:="build/main"

build:
    odin build src -out:{{out}}
run arg="":
    just build
    {{out}} {{arg}}
