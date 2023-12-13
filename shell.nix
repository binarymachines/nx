{ nixpkgs ? import <nixpkgs> {} }:

nixpkgs.mkShell {
  buildInputs = [
    nixpkgs.poetry
    nixpkgs.gh
    nixpkgs.docker
    nixpkgs.docker-compose
    nixpkgs.alembic
    nixpkgs.pam
    nixpkgs.postgresql
    nixpkgs.stdenv.cc.cc.lib
  ];
}

