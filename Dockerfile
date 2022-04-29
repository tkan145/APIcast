FROM registry.access.redhat.com/ubi8:8.5

ARG OPENRESTY_RPM_VERSION="1.19.3"

LABEL summary="3scale's API gateway (APIcast) is an OpenResty application which consists of two parts: Nginx configuration and Lua files." \
      description="APIcast is not a standalone API gateway therefore it needs connection to the 3scale API management platform. The container includes OpenResty and uses LuaRocks to install dependencies (rocks are installed in the application folder)." \
      io.k8s.description="APIcast is not a standalone API gateway therefore it needs connection to the 3scale API management platform. The container includes OpenResty and uses LuaRocks to install dependencies (rocks are installed in the application folder)." \
      io.k8s.display-name="3scale API gateway (APIcast)" \
      io.openshift.expose-services="8080:apicast" \
      io.openshift.tags="integration, nginx, lua, openresty, api, gateway, 3scale, rhamp" \
      maintainer="3scale-engineering@redhat.com"

WORKDIR /tmp

ENV AUTO_UPDATE_INTERVAL=0 \
    # The $HOME is not set by default, but some applications needs this variable
    HOME=/opt/app-root/src \
    PATH=/opt/app-root/src/bin:/opt/app-root/bin:$PATH \
    PLATFORM="el8"

RUN sed -i s/enabled=./enabled=0/g /etc/yum/pluginconf.d/subscription-manager.conf

RUN dnf install -y 'dnf-command(config-manager)'

RUN yum config-manager --add-repo http://packages.dev.3sca.net/dev_packages_3sca_net.repo

RUN PKGS="perl-interpreter-5.26.3-420.el8 libyaml-devel-0.1.7-5.el8 m4 openssl-devel git gcc make curl openresty-resty-${OPENRESTY_RPM_VERSION} luarocks-2.3.0-5.el8 opentracing-cpp-devel-1.3.0-26.el8arches libopentracing-cpp1-1.3.0-26.el8arches jaegertracing-cpp-client openresty-opentracing-${OPENRESTY_RPM_VERSION}" && \
    mkdir -p "$HOME" && \
    yum -y --setopt=tsflags=nodocs install $PKGS && \
    rpm -V $PKGS && \
    yum clean all -y

COPY site_config.lua /usr/share/lua/5.1/luarocks/site_config.lua
COPY config-*.lua /usr/local/openresty/config-5.1.lua

ENV PATH="./lua_modules/bin:/usr/local/openresty/luajit/bin/:${PATH}" \
    LUA_PATH="./lua_modules/share/lua/5.1/?.lua;./lua_modules/share/lua/5.1/?/init.lua;/usr/lib64/lua/5.1/?.lua;/usr/share/lua/5.1/?.lua" \
    LUA_CPATH="./lua_modules/lib/lua/5.1/?.so;;" \
    LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/opt/app-root/lib"

RUN luarocks install --server=http://luarocks.org/dev lua-rover && \
    rover -v && \
    yum -y remove luarocks && \
    ln -s /usr/bin/rover /usr/local/openresty/luajit/bin/ && \
    chmod g+w "${HOME}/.cache" && \
    rm -rf /var/cache/yum && yum clean all -y && \
    rm -rf "${HOME}/.cache/luarocks" ./*

COPY gateway/. /opt/app-root/src/

RUN mkdir -p /opt/app-root/src/logs && \
    useradd -u 1001 -r -g 0 -d ${HOME} -s /sbin/nologin -c "Default Application User" default && \
    rm -r /usr/local/openresty/nginx/logs && \
    ln -s /opt/app-root/src/logs /usr/local/openresty/nginx/logs && \
    ln -s /dev/stdout /opt/app-root/src/logs/access.log && \
    ln -s /dev/stderr /opt/app-root/src/logs/error.log && \
    mkdir -p /usr/local/share/lua/ && \
    chmod g+w /usr/local/share/lua/ && \
    mkdir -p /usr/local/openresty/nginx/{client_body_temp,fastcgi_temp,proxy_temp,scgi_temp,uwsgi_temp} && \
    chown -R 1001:0 /opt/app-root /usr/local/share/lua/ /usr/local/openresty/nginx/{client_body_temp,fastcgi_temp,proxy_temp,scgi_temp,uwsgi_temp}

RUN ln --verbose --symbolic /opt/app-root/src/bin /opt/app-root/bin && \
    ln --verbose --symbolic /opt/app-root/src/http.d /opt/app-root/http.d && \
    ln --verbose --symbolic --force /etc/ssl/certs/ca-bundle.crt "/opt/app-root/src/conf" && \
    chmod --verbose g+w "${HOME}" "${HOME}"/* "${HOME}/http.d" && \
    chown -R 1001:0 /opt/app-root

RUN ln --verbose --symbolic /opt/app-root/src /opt/app-root/app && \
    ln --verbose --symbolic /opt/app-root/bin /opt/app-root/scripts

ENV LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/opt/app-root/lib"

WORKDIR /opt/app-root/app

RUN git config --global url.https://github.com/.insteadOf git://github.com/

RUN EXTRA_CFLAGS="-DHAVE_EVP_KDF_CTX=1" rover install --path . --without development --without test

RUN yum -y remove libyaml-devel m4 openssl-devel git gcc && rm -rf /var/cache/yum && \
    yum clean all -y

USER 1001

ENV LUA_CPATH "./?.so;/usr/lib64/lua/5.1/?.so;/usr/lib64/lua/5.1/loadall.so;/usr/local/lib64/lua/5.1/?.so"
ENV LUA_PATH "/usr/lib64/lua/5.1/?.lua;/usr/local/share/lua/5.1/?.lua;/usr/local/share/lua/5.1/*/?.lua;"

WORKDIR /opt/app-root
ENTRYPOINT ["container-entrypoint"]
CMD ["scripts/run"]
