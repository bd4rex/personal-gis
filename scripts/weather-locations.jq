def population:
  (.properties.population // "0"
    | tostring
    | gsub("[^0-9.]"; "")
    | tonumber? // 0);

map(select(.geometry.type == "Point" and (.properties.name // .properties["name:zh"]))) as $all
| ($all
    | map(select(
        .properties["place:CN"] == "prefecture-level_city"
        or ((.properties.capital // "99" | tonumber? // 99) <= 5)
      ))) as $primary
| (if ($primary | length) > 0
   then $primary
   else ($all | sort_by(population) | reverse | .[0:30])
   end)
| map({
    regionId: $regionId,
    province: $regionName,
    name: (.properties["name:zh-Hans"] // .properties["name:zh"] // .properties.name),
    latitude: .geometry.coordinates[1],
    longitude: .geometry.coordinates[0],
    population: population
  })
| unique_by(.name)
