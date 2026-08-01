(function registerGissMapStyle(global) {
  const nameField = [
    "coalesce",
    ["get", "name:zh"],
    ["get", "name"],
    ["get", "name:latin"],
    ["get", "name_en"]
  ];

  const palettes = {
    standard: {
      background: "#f2efe9",
      forest: "#add19e",
      grass: "#cdebb0",
      wetland: "#b8d9c0",
      residential: "#e8e0d8",
      industrial: "#dfd1d6",
      commercial: "#f2dad9",
      school: "#f0e6b2",
      hospital: "#f5d6d6",
      water: "#aad3df",
      waterLine: "#79b6cb",
      building: "#d8d0c8",
      text: "#222222",
      poi: "#2a6f9e"
    },
    explore: {
      background: "#f4f1e8",
      forest: "#9fc78e",
      grass: "#c4e5a4",
      wetland: "#a8d1bb",
      residential: "#e5ddd2",
      industrial: "#d9cbd2",
      commercial: "#efd0ce",
      school: "#eadf9f",
      hospital: "#f2caca",
      water: "#9bcddd",
      waterLine: "#64aac3",
      building: "#d3c8bd",
      text: "#17211c",
      poi: "#1f6e98"
    }
  };

  function expandLayers(datasets, definitions) {
    const layers = [];
    const groups = new Map();
    for (const definition of definitions) {
      if (definition.global) {
        layers.push(definition.layer);
        if (definition.groups) groups.set(definition.layer.id, definition.groups);
        continue;
      }
      for (const dataset of datasets) {
        const layer = {
          ...definition.layer,
          id: `${dataset.id}-${definition.layer.id}`,
          source: dataset.id
        };
        layers.push(layer);
        groups.set(layer.id, definition.groups || []);
      }
    }
    return { layers, groups };
  }

  function create(catalog, themeName) {
    const palette = palettes[themeName] || palettes.standard;
    const sources = Object.fromEntries(
      catalog.datasets.map((dataset) => [
        dataset.id,
        dataset.source || {
          type: "vector",
          url: `pmtiles://${window.location.origin}${dataset.url}`,
          attribution: '© <a href="https://openmaptiles.org/">OpenMapTiles</a> © <a href="https://www.openstreetmap.org/copyright">OpenStreetMap contributors</a>'
        }
      ])
    );

    const lineGeometry = ["match", ["geometry-type"], ["LineString", "MultiLineString"], true, false];
    const poiIcon = [
      "match",
      ["coalesce", ["get", "subclass"], ["get", "class"], ""],
      "restaurant", "restaurant_11",
      "cafe", "cafe_11",
      "fast_food", "fast_food_11",
      "hotel", "lodging_11",
      "motel", "lodging_11",
      "hostel", "lodging_11",
      "hospital", "hospital_11",
      "clinic", "hospital_11",
      "pharmacy", "pharmacy_11",
      "school", "school_11",
      "college", "college_11",
      "university", "college_11",
      "library", "library_11",
      "museum", "museum_11",
      "art_gallery", "art_gallery_11",
      "cinema", "cinema_11",
      "theatre", "theatre_11",
      "supermarket", "shop_11",
      "convenience", "shop_11",
      "bakery", "bakery_11",
      "fuel", "fuel_11",
      "parking", "parking_11",
      "bus_station", "bus_11",
      "railway", "railway_11",
      "airport", "airport_11",
      "police", "police_11",
      "fire_station", "fire_station_11",
      "post_office", "post_11",
      "bank", "bank_11",
      "toilets", "toilets_11",
      "drinking_water", "drinking_water_11",
      "attraction", "attraction_11",
      "park", "park_11",
      "playground", "playground_11",
      "place_of_worship", "place_of_worship_11",
      "information", "information_11",
      "town_hall", "town_hall_11",
      ["match", ["get", "class"], "shop", "shop_11", "railway", "railway_11", "circle_11"]
    ];
    const definitions = [
      {
        global: true,
        layer: { id: "background", type: "background", paint: { "background-color": palette.background } }
      },
      {
        groups: ["land"],
        layer: {
          id: "landcover",
          type: "fill",
          "source-layer": "landcover",
          paint: {
            "fill-color": ["match", ["get", "class"], "wood", palette.forest, "forest", palette.forest, "wetland", palette.wetland, "grass", palette.grass, "scrub", palette.grass, palette.grass],
            "fill-opacity": ["interpolate", ["linear"], ["zoom"], 5, 0.25, 12, 0.62]
          }
        }
      },
      {
        groups: ["land"],
        layer: {
          id: "landuse",
          type: "fill",
          "source-layer": "landuse",
          minzoom: 8,
          paint: {
            "fill-color": ["match", ["get", "class"], "residential", palette.residential, "industrial", palette.industrial, "commercial", palette.commercial, "school", palette.school, "hospital", palette.hospital, "cemetery", "#cbd9b8", palette.residential],
            "fill-opacity": ["interpolate", ["linear"], ["zoom"], 8, 0.2, 13, 0.56]
          }
        }
      },
      {
        groups: ["land"],
        layer: { id: "park", type: "fill", "source-layer": "park", paint: { "fill-color": palette.grass, "fill-opacity": 0.76 } }
      },
      {
        groups: ["land"],
        layer: { id: "water", type: "fill", "source-layer": "water", paint: { "fill-color": palette.water } }
      },
      {
        groups: ["land"],
        layer: {
          id: "waterway",
          type: "line",
          "source-layer": "waterway",
          minzoom: 8,
          layout: { "line-cap": "round", "line-join": "round" },
          paint: { "line-color": palette.waterLine, "line-width": ["interpolate", ["exponential", 1.3], ["zoom"], 8, 0.45, 13, 1.3, 16, 3.6] }
        }
      },
      {
        groups: ["land"],
        layer: {
          id: "aeroway-area",
          type: "fill",
          "source-layer": "aeroway",
          minzoom: 10,
          filter: ["match", ["geometry-type"], ["Polygon", "MultiPolygon"], true, false],
          paint: { "fill-color": "#ded7e8", "fill-opacity": 0.58 }
        }
      },
      {
        groups: ["roads"],
        layer: {
          id: "aeroway-line",
          type: "line",
          "source-layer": "aeroway",
          minzoom: 10,
          filter: lineGeometry,
          paint: { "line-color": "#c6bbd4", "line-width": ["interpolate", ["linear"], ["zoom"], 10, 2, 16, 10] }
        }
      },
      {
        groups: ["land"],
        layer: {
          id: "boundary",
          type: "line",
          "source-layer": "boundary",
          filter: ["all", ["!=", ["get", "maritime"], 1]],
          paint: { "line-color": "#9d8da3", "line-dasharray": [3, 2], "line-opacity": 0.7, "line-width": ["interpolate", ["linear"], ["zoom"], 5, 0.6, 14, 2] }
        }
      }
    ];

    const roadClasses = [
      { id: "minor", classes: ["minor", "service", "track", "path"], minzoom: 12, casing: "#d8d4cf", fill: "#ffffff", widths: [0.7, 2.2, 7.5, 0.35, 1.35, 5.5] },
      { id: "secondary", classes: ["secondary", "tertiary"], minzoom: 8, casing: "#d8c788", fill: "#fff7b3", widths: [1, 2.4, 8.5, 0.6, 1.7, 6.4] },
      { id: "primary", classes: ["primary", "trunk"], minzoom: 6, casing: "#d69b55", fill: "#fcd6a4", widths: [1.1, 2.6, 12, 0.7, 1.9, 10] },
      { id: "motorway", classes: ["motorway"], minzoom: 5, casing: "#d8667f", fill: "#e892a2", widths: [1, 2.6, 14, 0.65, 1.85, 11] }
    ];

    for (const road of roadClasses) {
      const filter = ["all", lineGeometry, ["in", ["get", "class"], ["literal", road.classes]]];
      definitions.push(
        {
          groups: ["roads"],
          layer: {
            id: `road-${road.id}-casing`, type: "line", "source-layer": "transportation", minzoom: road.minzoom, filter,
            layout: { "line-cap": "round", "line-join": "round" },
            paint: { "line-color": road.casing, "line-width": ["interpolate", ["exponential", 1.2], ["zoom"], road.minzoom, road.widths[0], 14, road.widths[1], 18, road.widths[2]] }
          }
        },
        {
          groups: ["roads"],
          layer: {
            id: `road-${road.id}`, type: "line", "source-layer": "transportation", minzoom: road.minzoom, filter,
            layout: { "line-cap": "round", "line-join": "round" },
            paint: { "line-color": road.fill, "line-width": ["interpolate", ["exponential", 1.2], ["zoom"], road.minzoom, road.widths[3], 14, road.widths[4], 18, road.widths[5]] }
          }
        }
      );
    }

    definitions.push(
      {
        groups: ["roads"],
        layer: {
          id: "rail", type: "line", "source-layer": "transportation", minzoom: 9,
          filter: ["all", lineGeometry, ["in", ["get", "class"], ["literal", ["rail", "transit"]]]],
          paint: { "line-color": "#777777", "line-width": ["interpolate", ["linear"], ["zoom"], 9, 0.5, 17, 2], "line-opacity": 0.78 }
        }
      },
      {
        groups: ["buildings"],
        layer: {
          id: "building", type: "fill", "source-layer": "building", minzoom: 13,
          paint: { "fill-color": palette.building, "fill-outline-color": "#c2b8ae", "fill-opacity": ["interpolate", ["linear"], ["zoom"], 13, 0.38, 16, 0.78] }
        }
      },
      {
        groups: ["poi"],
        layer: {
          id: "poi-circle", type: "circle", "source-layer": "poi", minzoom: themeName === "explore" ? 12 : 13,
          filter: ["match", ["geometry-type"], ["Point", "MultiPoint"], true, false],
          paint: {
            "circle-radius": ["interpolate", ["linear"], ["zoom"], 12, 1.5, 17, 4.5],
            "circle-color": ["match", ["get", "class"], "park", "#3e8a5b", "hospital", "#d95b55", "school", "#b98b26", "railway", "#715a91", palette.poi],
            "circle-opacity": 0.82, "circle-stroke-width": 1, "circle-stroke-color": "#ffffff"
          }
        }
      },
      {
        groups: ["poi"],
        layer: {
          id: "poi-icon", type: "symbol", "source-layer": "poi", minzoom: themeName === "explore" ? 13 : 14,
          filter: ["match", ["geometry-type"], ["Point", "MultiPoint"], true, false],
          layout: {
            "icon-image": poiIcon,
            "icon-size": ["interpolate", ["linear"], ["zoom"], 13, 0.82, 17, 1],
            "icon-padding": 2,
            "icon-allow-overlap": false
          }
        }
      },
      {
        groups: ["poi"],
        layer: {
          id: "mountain-peak", type: "circle", "source-layer": "mountain_peak", minzoom: 10,
          paint: { "circle-radius": 2.5, "circle-color": "#7b5e48", "circle-stroke-color": "#fff", "circle-stroke-width": 1 }
        }
      },
      {
        groups: ["labels"],
        layer: {
          id: "place-label", type: "symbol", "source-layer": "place", minzoom: 5, filter: ["has", "name"],
          layout: { "text-field": nameField, "text-font": ["Noto Sans Regular"], "text-size": ["interpolate", ["linear"], ["zoom"], 5, 11, 9, 14, 13, 19], "text-padding": 4 },
          paint: { "text-color": palette.text, "text-halo-color": "rgba(255,255,255,0.9)", "text-halo-width": 1.4 }
        }
      },
      {
        groups: ["labels", "roads"],
        layer: {
          id: "road-label", type: "symbol", "source-layer": "transportation_name", minzoom: 11, filter: ["has", "name"],
          layout: { "symbol-placement": "line", "text-field": nameField, "text-font": ["Noto Sans Regular"], "text-size": ["interpolate", ["linear"], ["zoom"], 11, 10, 16, 12], "text-padding": 3, "text-rotation-alignment": "map" },
          paint: { "text-color": "#4c5350", "text-halo-color": "rgba(255,255,255,0.9)", "text-halo-width": 1 }
        }
      },
      {
        groups: ["labels", "land"],
        layer: {
          id: "water-label", type: "symbol", "source-layer": "water_name", minzoom: 8, filter: ["has", "name"],
          layout: { "text-field": nameField, "text-font": ["Noto Sans Italic"], "text-size": 11 },
          paint: { "text-color": "#3e829c", "text-halo-color": "rgba(255,255,255,0.84)", "text-halo-width": 1 }
        }
      },
      {
        groups: ["labels", "poi"],
        layer: {
          id: "peak-label", type: "symbol", "source-layer": "mountain_peak", minzoom: 12, filter: ["has", "name"],
          layout: { "text-field": nameField, "text-font": ["Noto Sans Regular"], "text-size": 10, "text-offset": [0, 0.8], "text-anchor": "top" },
          paint: { "text-color": "#654b39", "text-halo-color": "rgba(255,255,255,0.9)", "text-halo-width": 1 }
        }
      },
      {
        groups: ["labels", "poi"],
        layer: {
          id: "poi-label", type: "symbol", "source-layer": "poi", minzoom: themeName === "explore" ? 14 : 15, filter: ["has", "name"],
          layout: { "text-field": nameField, "text-font": ["Noto Sans Regular"], "text-size": 11, "text-offset": [0, 0.75], "text-anchor": "top", "text-padding": 3 },
          paint: { "text-color": "#315e75", "text-halo-color": "rgba(255,255,255,0.9)", "text-halo-width": 1 }
        }
      },
      {
        groups: ["labels", "buildings"],
        layer: {
          id: "house-number", type: "symbol", "source-layer": "housenumber", minzoom: 17, filter: ["has", "housenumber"],
          layout: { "text-field": ["get", "housenumber"], "text-font": ["Noto Sans Regular"], "text-size": 10 },
          paint: { "text-color": "#6d625c", "text-halo-color": "rgba(255,255,255,0.9)", "text-halo-width": 1 }
        }
      }
    );

    const expanded = expandLayers(catalog.datasets, definitions);
    return {
      style: {
        version: 8,
        name: `GISS ${themeName}`,
        glyphs: `${window.location.origin}/assets/glyphs/{fontstack}/{range}.pbf`,
        sprite: `${window.location.origin}/assets/sprites/ofm_f384/ofm`,
        sources,
        layers: expanded.layers
      },
      groups: expanded.groups
    };
  }

  global.GissMapStyle = { create };
})(window);
