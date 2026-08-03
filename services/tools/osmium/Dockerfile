FROM debian@sha256:60eac759739651111db372c07be67863818726f754804b8707c90979bda511df

RUN apt-get update \
    && apt-get install --no-install-recommends -y osmium-tool jq ca-certificates \
    && rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["osmium"]
