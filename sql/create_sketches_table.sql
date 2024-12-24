CREATE OR REPLACE FUNCTION create_bbox(geom geometry, sketch_id integer) RETURNS real[]
  LANGUAGE plpgsql IMMUTABLE SECURITY DEFINER
  AS $$
  declare
    bbox real[];
  begin
    if geom is null then
      return null;
    end if;
    select array[st_xmin(geom)::real, st_ymin(geom)::real, st_xmax(geom)::real, st_ymax(geom)::real] into bbox;
    return bbox;
  end;
$$;

CREATE TABLE sketches (
    id SERIAL,
    -- name text NOT NULL,
    -- sketch_class_id integer NOT NULL,
    -- user_id integer,
    -- collection_id integer,
    -- copy_of integer,
    user_geom geometry(Geometry,4326),
    geom geometry(Geometry,4326),
    -- folder_id integer,
    -- properties jsonb DEFAULT '{}'::jsonb NOT NULL,
    num_vertices integer GENERATED ALWAYS AS (st_npoints(COALESCE(geom, user_geom))) STORED,
    -- form_element_id integer,
    -- response_id integer,
    mercator_geometry geometry(Geometry,3857) GENERATED ALWAYS AS (st_transform(COALESCE(geom, user_geom), 3857)) STORED,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    -- post_id integer,
    shared_in_forum boolean DEFAULT false NOT NULL,
    bbox real[] GENERATED ALWAYS AS (create_bbox(COALESCE(geom, user_geom), id)) STORED,
    area float GENERATED ALWAYS AS (ST_Area(geom)) STORED
);
