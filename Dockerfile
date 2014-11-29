
# Gitolite server by Luispa, Nov 2014
#
# -----------------------------------------------------
#

# Desde donde parto...
#
FROM debian:jessie

# Basado en la idea original de: https://registry.hub.docker.com/u/elsdoerfer/gitolite/
#
MAINTAINER Luis Palacios <luis@luispa.com>

# Pido que el frontend de Debian no sea interactivo
ENV DEBIAN_FRONTEND noninteractive

# Actualizo el sistema operativo + SSH y GIT
#
RUN apt-get update && \
    apt-get -y install locales \
                       git \
                       openssh-server \
                       sudo
                             
# Preparo locales
#
RUN locale-gen es_ES.UTF-8
RUN locale-gen en_US.UTF-8
RUN dpkg-reconfigure locales

# Preparo el timezone para Madrid
#
RUN echo "Europe/Madrid" > /etc/timezone; dpkg-reconfigure -f noninteractive tzdata

# NOTA: Comentar al terminar las pruebas
# Permito que root pueda entrar mientras hago pruebas.
#
#RUN echo 'root:dock123456' | chpasswd
#RUN sed -i 's/PermitRootLogin without-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# Importante para que sshd funcione... 
#
RUN mkdir /var/run/sshd

# Creo el usuario git en /home/git
# Notar que le asigno el mismo UID/GID 1600/1600 que tengo
# asignado al usuario git:git en el Host, de modo que el
# Volumen donde estan los repositorios aparece con el mismo uid/gid
RUN groupadd -g 1600 git
RUN useradd -u 1600 -g git -m -d /home/git -s /bin/bash git

# Descargo e instalo gitolite
#
RUN su - git -c 'git clone git://github.com/sitaramc/gitolite'
RUN su - git -c 'mkdir -p $HOME/bin \
              && gitolite/install -to $HOME/bin'

# Le pongo todos los permisos correctos al usuario
#
RUN chown -R git:git /home/git

# Para evitar error de login
# http://stackoverflow.com/questions/22547939/docker-gitlab-container-ssh-git-login-error
#
RUN sed -i '/session    required     pam_loginuid.so/d' /etc/pam.d/sshd

# Ejecutable a lanzar cuando ararnque el contenedor, ahí es donde se hace
# todo el trabajo sucio para actiar bien el servicio gitolite
#
ADD ./init.sh /init.sh
RUN chmod +x /init.sh

