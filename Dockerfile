# syntax=docker/dockerfile:1.7

# Build stage: install kotoshu and pre-warm dictionaries into a writable cache.
ARG RUBY_VERSION=3.4
FROM ruby:${RUBY_VERSION}-slim AS builder

ARG KOTOSHU_PREWARM_LANGS="en"

# kotoshu ships an optional Rust native extension (the accelerator;
# the pure-Ruby engine is the default backend and always present).
# ruby:slim has neither make nor cargo, so the gem cannot install at
# all without them (found by the plan-125 version guard, 2026-09-12):
# rb_sys builds the ext during `gem install` and fails hard on a
# missing toolchain. build-essential satisfies make+cc; rb_sys
# installs its pinned Rust toolchain itself when RB_SYS_FORCE...=true
# (the extconf's documented override), so no rustup layer here.
RUN apt-get update \
    && apt-get install -y --no-install-recommends git ca-certificates build-essential \
    && rm -rf /var/lib/apt/lists/*
ENV RB_SYS_FORCE_INSTALL_RUST_TOOLCHAIN=true

WORKDIR /build

# Install kotoshu from RubyGems. Use KOTOSHU_VERSION to pin.
ARG KOTOSHU_VERSION=""
RUN if [ -n "$KOTOSHU_VERSION" ]; then \
      gem install kotoshu --version "$KOTOSHU_VERSION" --no-document; \
    else \
      gem install kotoshu --no-document; \
    fi

# Pre-warm dictionaries. This is the slow step we want cached in the image.
RUN mkdir -p /root/.cache/kotoshu \
    && for lang in $KOTOSHU_PREWARM_LANGS; do \
         echo "pre-warming $lang"; \
         ruby -e "require 'kotoshu'; Kotoshu.setup(:$lang)" || \
           echo "  WARN: $lang pre-warm failed; will retry at runtime"; \
       done


# Runtime stage: keep only what's needed.
FROM ruby:${RUBY_VERSION}-slim AS runtime

# Copy the installed gem tree and the warmed cache.
COPY --from=builder /usr/local/bundle /usr/local/bundle
COPY --from=builder /root/.cache/kotoshu /root/.cache/kotoshu

# Non-root is safer in CI, but the cache lives under /root; default to root.
WORKDIR /work

# Offline by default — the whole point is no per-run downloads.
ENV KOTOSHU_OFFLINE=1 \
    XDG_CACHE_HOME=/root/.cache \
    LANG=C.UTF-8

# Sanity check at build time: the gem is installed and CLI runs.
RUN kotoshu --version

ENTRYPOINT ["kotoshu"]
CMD ["--help"]
