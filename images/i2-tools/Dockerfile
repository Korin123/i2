# i2-tools: ADT's i2a_tools_redhat image (i2 Analyze tools) with our assembled i2
# configuration at /opt/configuration, as ADT mounts it for run_i2_analyze_tool.
# Used by the match-rules Job (runAdminCommand.sh). Built by scripts/30-build-images.sh.
ARG BASE_IMAGE
FROM ${BASE_IMAGE}
COPY --chown=i2analyze:0 configuration /opt/configuration
COPY --chown=i2analyze:0 --chmod=755 match-rules.sh /opt/match-rules.sh
