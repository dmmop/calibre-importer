# Use an Alpine linux base image with GNU libc (aka glibc) pre-installed, courtesy of Vlad Frolov
FROM frolvlad/alpine-glibc

MAINTAINER dmmop

#########################################
##        ENVIRONMENTAL CONFIG         ##
#########################################
# Calibre environment variables
ENV CALIBRE_LIBRARY_DIRECTORY=/opt/calibredb/library

# Auto-import directory
ENV CALIBRE_IMPORT_DIRECTORY=/opt/calibredb/import

# Outputs extensions
ENV CALIBRE_OUTPUT_EXTENSIONS="mobi epub"

# File watcher delay (s)econd, (m)inutes, (h)ours, (d)ays
ENV DELAY_TIME="1m"

# Flag for automatically updating to the latest version on startup
ENV AUTO_UPDATE=0

#########################################
##         DEPENDENCY INSTALL          ##
#########################################
RUN apk update && \
    apk add --no-cache --upgrade \
    bash \
    ca-certificates \
    python \
    wget \
    gcc \
    mesa-gl \
    imagemagick \
    qt5-qtbase-x11 \
    xdg-utils \
    xz && \
#########################################
##            APP INSTALL              ##
#########################################
    wget -O- https://raw.githubusercontent.com/kovidgoyal/calibre/master/setup/linux-installer.py | python -c "import sys; main=lambda:sys.stderr.write('Download failed\n'); exec(sys.stdin.read()); main(install_dir='/opt', isolated=True)" && \
    rm -rf /tmp/calibre-installer-cache

#########################################
##            Script Setup             ##
#########################################
COPY auto_import.sh /opt/auto_import.sh
RUN chmod a+x /opt/auto_import.sh

#########################################
##         EXPORTS AND VOLUMES         ##
#########################################
VOLUME /opt/calibredb/import
VOLUME /opt/calibredb/library

#########################################
##           Startup Command           ##
#########################################
CMD ["/bin/bash", "/opt/auto_import.sh"]
