#!/bin/sh

#
# Basado en el trabajo original de:
# https://registry.hub.docker.com/u/elsdoerfer/gitolite/
#

#
# Este es el primer programa que se ejecutará al rrancar el contenedor
# del servidore gitolite. Básciamente ejecuta un Servidor SSH pero
# antes anailza qué es lo que se encuentra y si es un contenedor
# recien creado realiza una serie de configuraciones previas
#


# Cambio al directorio del usuario GIT
cd /home/git


# Averiguar si es una instalación nueva
#
INSTALACION_NUEVA="no"
if [ ! -d ./.gitolite ] ; then
    INSTALACION_NUEVA="si"
fi


# Asegurarme de que mi directorio .ssh tiene los permisos apropiados
#
echo "-------------------------------------------------------------------------------"
echo "--  PREPARAR EL ENTORNO                                                --------"
echo "-------------------------------------------------------------------------------"
if [ -d ./.ssh ]; then
    echo "Me aseguro que ./.ssh tiene los permisos apropiados"
    chown -R git:git ./.ssh
fi


# Me aseguro de mostrar cual es la clave publica del usuario git dentro del contenedor
# Si no la tiene la creo, va a necesitarse en entornos donde se usa mirroring.
#
if [ ! -f ./.ssh/id_rsa ]; then
   echo "Creo mi clave public/privada: .ssh/id_rsa"  
   su git -c "ssh-keygen -f /home/git/.ssh/id_rsa  -t rsa -N ''"
fi
echo "Clave pública del usuario git:"
echo "_______________________________________________________________________________"
cat /home/git/.ssh/id_rsa.pub
echo "_______________________________________________________________________________"


# Soporte de hosts de confianza (para setups con mirroring)
#
if [ ! -f ./.ssh/known_hosts ]; then
    if [ -n "$TRUST_HOSTS" ]; then
        echo "Genero un fichero known_hosts con el contenido de la variable \$TRUST_HOSTS"
        su git -c "ssh-keyscan -H $TRUST_HOSTS > /home/git/.ssh/known_hosts"
    fi
fi

#
# Si en el repositorio existe un fichero .gitolite.rc lo copio
#
if [ -f ./repositories/.gitolite.rc ]; then
    echo "Copio el fihcero .gitolite.rc"
    cp ./repositories/.gitolite.rc ./
    chown git:git .gitolite.rc
fi

# Dependiendo del tipo de instalación (nueva o existente)...
#
if [ ${INSTALACION_NUEVA} = "si" ] ; then
    #
    # Tengo el directorio de repositorios?
    if [ -d ./repositories ] ; then

        # Ya existe ./repositories, tiene pinta que lo montaron con -v
        # y es muy probable que se trata de repositorios existentes
        chown -R git:git repositories

        #
        # Lo importante ¿REUTILIZO o CREO REPOSITORIO NUEVO?
        #
        if [ -d ./repositories/gitolite-admin.git ]; then

            # Si existe gitolite-admin.git es que estamos ante una reutilización de
            # un repositorio externo ya existente, así que actúo en consecuencia
            #
		    echo "-------------------------------------------------------------------------------"
		    echo "--  INSTALACIÓN NUEVA CON REPOSITORIOS YA EXISTENTES                   --------"
		    echo "-------------------------------------------------------------------------------"

            echo "-- REPO Existente: INTEGRO con un repositorio exitente"
            mv ./repositories/gitolite-admin.git ./repositories/gitolite-admin.git-tmp
            su git -c "bin/gitolite setup -a dummy"
            rm -rf ./repositories/gitolite-admin.git
            mv ./repositories/gitolite-admin.git-tmp ./repositories/gitolite-admin.git

            echo "-- REPO Existente: PERSONALIZO el fichero .gitolite.rc"
            rcfile=/home/git/.gitolite.rc
            sed -i "s/GIT_CONFIG_KEYS.*=>.*''/GIT_CONFIG_KEYS => \"${GIT_CONFIG_KEYS}\"/g" $rcfile
            if [ -n "$LOCAL_CODE" ]; then
                sed -i "s|# LOCAL_CODE.*=>.*$|LOCAL_CODE => \"${LOCAL_CODE}\",|" $rcfile
            fi
 
            echo "-- REPO Existente: IMPORTO gitolite.conf y keydir/* desde gitolite-admin.git"
            su git -c "mkdir ~/tmp                                                     && \
                       cd ~/tmp                                                        && \
                       git clone /home/git/repositories/gitolite-admin.git             && \
                       cp -R ~/tmp/gitolite-admin/conf/gitolite.conf ~/.gitolite/conf  && \
                       cp -R ~/tmp/gitolite-admin/keydir ~/.gitolite                   && \
                       rm -fr ~/tmp"
            su git -c "GL_LIBDIR=$(/home/git/bin/gitolite query-rc GL_LIBDIR) PATH=$PATH:/home/git/bin gitolite compile"
            
            # Arreglo los links que puedan estar mal en el repositorio existente
            echo "-- REPO Existente: Actualizo los simbolic links"
            su git -c "GL_LIBDIR=$(/home/git/bin/gitolite query-rc GL_LIBDIR) PATH=$PATH:/home/git/bin gitolite setup"
            
        else

		    echo "-------------------------------------------------------------------------------"
		    echo "--  INSTALACIÓN NUEVA VACÍA, CREO gitolite-admin.git                   --------"
		    echo "-------------------------------------------------------------------------------"

            # El repositorio gitolite-admin.git no existe, así que creo uno desde cero
            # Es importante tener la clave SSH_KEY o... no podremos hacerlo
            
            echo "-- REPO Nuevo: Creo un repositorio nuevo"
            if [ -n "$SSH_KEY" ]; then
                echo "-- REPO Nuevo: IMPORTO la clave desde SSH_KEY y hago el gitolite setup"
                echo "$SSH_KEY" > /tmp/admin.pub
                su git -c "bin/gitolite setup -pk /tmp/admin.pub"
                rm /tmp/admin.pub
            else
                echo ""
                echo ""
                echo " ======= ERROR !!! No puedo crear un REPO nuevo porque no me han pasado la variable SSH_KEY !!!!"
                echo ""
                echo "         Ejecutar con: -e SSH_KEY=\"\$(cat \$FICHERO_CLAVE_SSH)\""
                echo ""
                exit 255
            fi    
        fi        
    fi

else
    echo "-------------------------------------------------------------------------------"
    echo "--  INSTALACIÓN EXISTENE                                               --------"
    echo "-------------------------------------------------------------------------------"
    echo "-- Simplemente ejecuto 'gitolite setup' para resincronizar"
    su git -c "bin/gitolite setup"
fi

echo
echo "==============================================================================="
echo "Ejecuto el programa: $*"
echo "==============================================================================="
echo
exec $*
