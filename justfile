out:="build/main"

build flag="":
    odin build src -out:{{out}} {{flag}} 

run arg="":
    just build
    {{out}} {{arg}}

run-debug arg="":
    just build -debug
    {{out}} {{arg}}
