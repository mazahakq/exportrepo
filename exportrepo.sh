#!/bin/bash
#############################################################
#       Script Export/Import/View Repo Packet Folder        #
#                      ver:2.0.0.2                          #
#                 Author: Nabokov G.V.                      #
#############################################################
#                                                           #
#                 Data pruf: 21.01.2021                     #
#############################################################
x=0
LOGIN=false
helmpacket="helm-v3.3.1-linux-amd64.tar.gz"
defaulttype="yum"
defaultrepo="nexus-kub"
defaultprogyum="kubectl"
defaultprogpip="pyodbc"
defaultproghelm="jenkins"
defaultprognuget="ProcessingAgent"
defaultprogdocker="sonatype/nexus3:latest"
defaultoperation="export"
defaultyumpacket="./packet"
defaultpippacket="./pip"
defaulthelmpacket="./helm"
defaultnugetpacket="./nuget"
defaultdockerpacket="./registry"
defaultyumurl="http://n7701-suimpporeg:8081/repository/yumrepo/rhel8/"
defaultpipurl="http://n7701-suimpporeg:8081/repository/piprepo/"
defaulthelmurl="http://n7701-suimpporeg:8081/repository/helmrepo/"
defaultnugeturl="http://n7701-suimpporeg:8081/repository/nugetrepo/"
defaultdockerurl="n7701-suimpporeg:5000/repository/registry/"
downloadfile="http://n7701-suimpporeg:8000/file/"
function helpfunc()
{
    echo "###########################################################################################"
    echo "HELP SCRIPTS"
    echo "Script Export/Import/View Repo Packet Folder"
    echo "###########################################################################################"
    echo "Grant:"
    echo "     sudo docker - download docker images"
    echo "     sudo yum    - view repos yum"
    echo "     sudo chown  - update perm file tar docker"
    echo "     sudo cp     - update nuget.exe"
    echo "Dependence:"
    echo "          packet: curl,docker-ce,tar, jq - sudo yum install curl docker-ce tar jq pip pip3 yum-utils"
    echo "          python: twine - pip3 install --user twine"
    echo "            helm: install guide:" 
    echo "                               download packet "$downloadfile$helmpacket
    echo "                               tar unpack, copy file helm to /usr/local/bin/"
    echo "           nuget: nuget - sudo yum install nuget"
    echo "                               sudo cp nuget.exe /usr/lib/mono/nuget/NuGet.exe"
    echo "Args:"    
    echo "  --packet - folder packet. Default:"
    echo "                                 yum: "$defaultyumpacket
    echo "                                 pip: "$defaultpippacket
    echo "                                helm: "$defaulthelmpacket
    echo "                               nuget: "$defaultnugetpacket
    echo "                     docker registry: "$defaultdockerpacket
    echo "  --url    - url repo.      Default:"
    echo "                                 yum: "$defaultyumurl
    echo "                                 pip: "$defaultpipurl
    echo "                                helm: "$defaulthelmurl
    echo "                               nuget: "$defaultnugeturl
    echo "                     docker registry: "$defaultdockerurl
    echo "  --type   - type repo: yum, pip, helm, nuget, docker. Default: "$defaulttype
    echo "  --op     - operation: export, view. Default: "$defaultoperation
    echo "  --login  - use username:password repository. Default: No login or Cache"
    echo "  --repo   - name repo WARNING one VIEW YUM. Default: "$defaultrepo
    echo "  --prog   - name download programm WARNING one IMPORT ALL. Default: "
    echo "                                 yum: "$defaultprogyum
    echo "                                 pip: "$defaultprogpip
    echo "                                helm: "$defaultproghelm
    echo "                               nuget: "$defaultprognuget
    echo "                     docker registry: "$defaultprogdocker
    echo "  --help   - help note"
    echo "Example:"
    echo "       exportrepo.sh --packet ./new --type yum"
    echo "###########################################################################################"
    echo "YUM    REPO: /etc/yum.repos.d/"
    echo "PIP    REPO: /etc/pip.conf - global, ~/.pypirc - Cred Repo"
    echo "HELM   REPO: /home/$USER/.config/helm/repositories.yaml"
    echo "NUGET  REPO: /home/$USER/.config/NuGet/NuGet.Config"
    echo "DOCKER REPO: /root/.docker/config.json"
    echo "###########################################################################################"
    exit 0
}

function error_exit {
  echo "$1" 1>&2
  exit 1
}

function import_repo {
  echo "START IMPORT"
  if [ $TYPE = "yum" ] ; then
    yumdownloader --downloadonly --resolve --destdir $PACKET $PROGRAMNAME
  elif [ $TYPE = "helm" ] ; then
    helm pull $PROGRAMNAME --username $USERREPO --password $PASSREPO --repo $URL -d $PACKET
    echo "Download of $URL $PROGRAMNAME to $PACKET"
  elif [ $TYPE = "nuget" ] ; then
    echo "NO IMPORT "$TYPE
  elif [ $TYPE = "pip" ] ; then
    pip3 download -d $PACKET $PROGRAMNAME
  elif [ $TYPE = "docker" ] ; then
    IMAGENAME=`echo "$PROGRAMNAME" | sed -r 's/(\/)//' | sed -r 's/(:)//'`
    IMAGENAMEFILE="$PACKET/$IMAGENAME.tar"
    sudo docker save -o $IMAGENAMEFILE $PROGRAMNAME
    sudo chown $(whoami) $IMAGENAMEFILE
    echo "Download of image $PROGRAMNAME to $IMAGENAMEFILE"
  fi
}

function view_repo {
  echo "START VIEW"
  if [ $TYPE = "yum" ] ; then
    yum repolist
    sudo yum repo-pkgs $REPONAME list
    #repoquery --repoid=$REPONAME -a
  elif [ $TYPE = "helm" ] ; then
    helm repo add check $URL --username $USERREPO --password $PASSREPO
    helm search repo check
    helm repo remove check
  elif [ $TYPE = "nuget" ] ; then
     echo "NO VIEW "$TYPE
  elif [ $TYPE = "pip" ] ; then
    if $LOGIN ; then
      LOGINTEXT="$USERREPO:$PASSREPO@"
    fi
    pip3 list -i http://$LOGINTEXT$URL
  elif [ $TYPE = "docker" ] ; then
    if $LOGIN ; then
        LOGINTEXT="--user \"$USERREPO:$PASSREPO\""
    fi
    URL=`echo "$URL" | sed -r 's/\/.+//'`
    EXECUTE="curl --silent $LOGINTEXT -X GET http://$URL/v2/_catalog"
    out=`eval $EXECUTE`   
    for IMAGETAG in `echo $out | jq .repositories[]`
    do
      echo $IMAGETAG | cut -d'"' -f 2
      EXECUTETAG="curl --silent $LOGINTEXT -X GET http://$URL/v2/$IMAGETAG/tags/list"
      outtag=`eval $EXECUTETAG`
      echo $outtag | jq .
    done 
  fi
}

function export_repo {
  echo "START UPLOAD"
  for FILE in `ls $PACKET -1`
  do
    if [[ $TYPE = "yum" || $TYPE = "helm" ]] ; then
      #echo "DOWNLOAD FILE $FILE TO REPO URL $URL"
      if $LOGIN ; then
        LOGINTEXT="--user \"$USERREPO:$PASSREPO\""
      fi
      EXECUTE="curl -k --silent -L -w \"\n%{http_code}\" $LOGINTEXT --upload-file \"$PACKET/$FILE\" \"$URL$FILE\""
      out=`eval $EXECUTE`
      http_status="${out##*$'\n'}"
      http_content="${out%$'\n'*}"
      if [ $http_status = "200" ] ; then #200 файл загружен
        result="UPLOAD FILE"
      elif [ $http_status = "400" ] ; then #400 файл существует
        result="FILE EXISTS"
      else
        result="ERROR"
      fi
    elif [ $TYPE = "nuget" ] ; then
      if $LOGIN ; then
        nuget add source $URL -name Nexus -username $USERREPO -password $PASSREPO
      fi
      EXECUTE="nuget push -Source Nexus $PACKET/$FILE"
      out=`eval $EXECUTE`
	  if [ -n "$(echo "$out" | grep 'Your package was pushed')" ] ; then 
        result="UPLOAD FILE"
      else
        if [ -n "$(echo "$out" | grep 'BadRequest')" ] ; then 
          result="FILE EXISTS"
        else
          result="ERROR"
        fi
      fi
    elif [ $TYPE = "pip" ] ; then
      if $LOGIN ; then
        LOGINTEXT="-u \"$USERREPO\" -p \"$PASSREPO\""
      fi
      EXECUTE="twine upload --repository-url \"$URL\" $LOGINTEXT --disable-progress-bar --skip-existing \"$PACKET/$FILE\" 2>&1"
      out=`eval $EXECUTE`
      countout=$(echo "$out" | wc -l)
      if [[ -n "$(echo "$out" | grep 'Uploading distributions')" && $countout < 4 ]] ; then     
        result="UPLOAD FILE"
        if [ -n "$(echo "$out" | grep 'because it appears to already exist')" ] ; then
          result="FILE EXISTS"
        fi
      else
        result="ERROR"
      fi
    elif [ $TYPE = "docker" ] ; then
      REPOSFILE=`tar xf $PACKET/$FILE repositories -O`
      NAMEIMAGE=`echo $REPOSFILE | jq 'keys'[0] | cut -d'"' -f 2`
      TAGIMAGE=`echo $REPOSFILE | jq .[] | jq keys[0] | cut -d'"' -f 2`  
      IMAGELOCALURL="$NAMEIMAGE:$TAGIMAGE"
      IMAGEREMOTEURL="$URL$IMAGELOCALURL"
      EXECUTELOAD=`sudo docker load -i $PACKET/$FILE`
      EXECUTENEWTAG=`sudo docker tag $IMAGELOCALURL $IMAGEREMOTEURL`
      #comsearch=`sudo docker images | grep '^namefile'`
      #nameimage=`echo $comsearch | awk '{print $1}'`
      #tagimage=`echo $comsearch | awk '{print $2}'`
      if sudo docker push $IMAGEREMOTEURL 1>&2 ; then
        EXECUTEDELETE=`sudo docker rmi $IMAGELOCALURL`
        result="UPLOAD IMAGE"
      else
        result="ERROR"
      fi
    fi
    echo "DOWNLOAD FILE $FILE TO REPO URL $URL RESULT - $result"
  done
}

#Проверка введены ли аргументы
if [ $# -eq 0 ] ; then
    echo "No arguments!!!"
fi

#Обработка ключей
for arg in $@
do
   if [ $arg = "--help" ] ; then
       helpfunc
   fi
   
   if [ $arg = "--login" ] ; then
       LOGIN=true
   fi  
   case $x in
       "--packet" )
           PACKET=$arg ;;
       "--url" )
           URL=$arg ;;
       "--type" )
           TYPE=$arg ;;
       "--op" )
           OPERATION=$arg ;;
       "--repo" )
           REPONAME=$arg ;;
       "--prog" )
           PROGRAMNAME=$arg ;;
   esac
   x=$arg
done

#Проверка ключа пакетов
if [ -z $PACKET ] ; then
    if [[ $TYPE = "yum" || -z $TYPE ]] ; then
       PACKET=$defaultyumpacket
    elif [ $TYPE = "pip" ] ; then
       PACKET=$defaultpippacket
    elif [ $TYPE = "helm" ] ; then
       PACKET=$defaulthelmpacket
    elif [ $TYPE = "nuget" ] ; then
       PACKET=$defaultnugetpacket
    elif [ $TYPE = "docker" ] ; then
       PACKET=$defaultdockerpacket
    fi
    echo "VAR DEFAULT PACKET: "$PACKET
else
  echo "VAR PACKET: "$PACKET
fi

#Проверка ключа типа репозитория
if [ -z $TYPE ] ; then
    TYPE=$defaulttype
    echo "VAR DEFAULT TYPE REPO: "$TYPE
else
  echo "VAR TYPE REPO: "$TYPE
fi

#Проверка ключа ссылки
if [ -z $URL ] ; then
    if [ $TYPE = "yum" ] ; then
       URL=$defaultyumurl
    elif [ $TYPE = "pip" ] ; then
       URL=$defaultpipurl
    elif [ $TYPE = "helm" ] ; then
       URL=$defaulthelmurl
    elif [ $TYPE = "nuget" ] ; then
       URL=$defaultnugeturl
    elif [ $TYPE = "docker" ] ; then
       URL=$defaultdockerurl
    fi
    echo "VAR DEFAULT URL: "$URL
else
  echo "VAR URL: "$URL
fi

#Проверка ключа авторизации
if $LOGIN ; then
    printf 'Username repo: '
    read USERREPO
    printf 'Password repo: '
    read -s PASSREPO
    echo ""
    if [[ $TYPE = "docker" && $OPERATION != "view" ]] ; then
      if ! sudo docker login -u $USERREPO --password $PASSREPO $URL ; then
        error_exit "No login docker"
      fi
    fi
else
  USERREPO=""
  PASSREPO=""
fi

#Проверка ключа репозитория
if [ -z $REPONAME ] ; then
    REPONAME=$defaultrepo
    echo "VAR DEFAULT REPONAME: "$REPONAME
else
  echo "VAR REPONAME: "$REPONAME
fi

#Проверка ключа операции
if [ -z $OPERATION ] ; then
    OPERATION=$defaultoperation
    echo "VAR DEFAULT OPERATION: "$OPERATION
else
  echo "VAR OPERATION: "$OPERATION
fi

#Проверка ключа имени программы для скачивания
if [ -z $PROGRAMNAME ] ; then
    if [ $TYPE = "yum" ] ; then
       PROGRAMNAME=$defaultprogyum
    elif [ $TYPE = "pip" ] ; then
       PROGRAMNAME=$defaultprogpip
    elif [ $TYPE = "helm" ] ; then
       PROGRAMNAME=$defaultproghelm
    elif [ $TYPE = "nuget" ] ; then
       PROGRAMNAME=$defaultprognuget
    elif [ $TYPE = "docker" ] ; then
       PROGRAMNAME=$defaultprogdocker
    fi
    echo "VAR DEFAULT PROGRAMNAME: "$PROGRAMNAME
else
  echo "VAR PROGRAMNAME: "$PROGRAMNAME
fi

#Выполнение операции (вызов функции)
if [ $OPERATION = "export" ] ; then
  #Экспорт в репозиторий
  export_repo
elif [ $OPERATION = "import" ] ; then
  #Импорт из репозитория
  import_repo
elif [ $OPERATION = "view" ] ; then
  #Просмотр репозитория
  view_repo
fi
