for archive in "$@"; do
  echo Fattening archive $archive
  cat << EOF > .fattenArchives.ar
create $archive.fat
addlib $archive
save
end
EOF
  ar -M < .fattenArchives.ar
  mv $archive.fat $archive
done
