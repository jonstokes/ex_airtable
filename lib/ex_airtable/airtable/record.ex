defmodule ExAirtable.Airtable.Record do
  @moduledoc """
  Struct for an Airtable Record. 

  This should directly match the results returned from any Airtable REST API endpoint that returns records.
  """

  @derive {Jason.Encoder, except: [:createdTime]}

  defstruct id: nil,
            fields: %{},
            createdTime: nil

  @type t :: %__MODULE__{
          id: String.t(),
          fields: %{},
          createdTime: String.t()
        }

  @doc """
  Convert a typical Airtable JSON response into a %Record{}
  """
  def from_map(map) when is_map(map) do
    %__MODULE__{
      id: Map.get(map, "id"),
      fields: Map.get(map, "fields", []),
      createdTime: Map.get(map, "createdTime")
    }
  end

  def from_map(other), do: other

  @doc """
  Given a table module, and a map of attributes that has been generated by
  `to_schema/2`, convert back into a valid %Record{}.

  This is essentially the reverse of `to_schema/2`.
  """
  def from_schema(table_module, attrs) when is_atom(table_module) and is_map(attrs) do
    reverse_schema = case apply(table_module, :schema, []) do
      nil ->
        Enum.reduce(attrs, %{}, fn {k, _v}, acc -> 
          if k == "airtable_id" || k == "inserted_at" do
            acc
          else
            Map.put(acc, k, k) 
          end
        end)
      schema ->
        Enum.reduce(schema, %{}, fn {k, v}, acc -> Map.put(acc, v, k) end)
    end

    fields = Enum.reduce(attrs, %{}, fn {k, v}, acc ->
      case Map.get(reverse_schema, k) do
        nil -> acc
        airtable_key -> Map.put(acc, airtable_key, v)
      end
    end)

    %__MODULE__{
      fields: fields,
      id: Map.get(attrs, :airtable_id, Map.get(attrs, "airtable_id", "")),
      createdTime: Map.get(attrs, :inserted_at, Map.get(attrs, "inserted_at", ""))
    }
  end

  @doc """
  Retrieve a field from within a record's fields

  Returns `nil` by default if no field matches.
  """
  def get(%__MODULE__{} = record, field, default \\ nil) do
    Map.get(record.fields, field, default)
  end

  @doc """
  Convert a record to an internal schema, mapping Airtable field names to local field names based on a `%{"Schema" => "map"}`.

  Returns a plain map, suitable for eg. Ecto casting + conversion.

  Note that fields not included in the `schema()` map (which is empty by default) will not be added to the final schema. This is by design, since we don't always care to deal with every field that's returned by Airtable in our local systems. However, it does mean that you will want to take care to include every field that you wish to convert into your local schema.

  If no schema map is given, the record fields are returned unmodified as a map.

  ## Examples

      iex> record = %ExAirtable.Airtable.Record{id: "1", fields: %{"AirtableField" => "value"}}

      iex> to_schema(record, %{"AirtableField" => "localfield"})
      %{"airtable_id" => "1", "localfield" => "value"}

      iex> to_schema(record, nil)
      %{"airtable_id" => "1", "AirtableField" => "value"}
  """
  def to_schema(%__MODULE__{} = record, nil) do
    Map.merge(
      %{"airtable_id" => record.id, "inserted_at" => record.createdTime},
      record.fields
    )
  end

  def to_schema(%__MODULE__{} = record, schema_map) when is_map(schema_map) do
    schema =
      Enum.reduce(record.fields, %{}, fn {key, val}, acc ->
        case Map.get(schema_map, key) do
          nil -> acc
          new_key -> Map.put(acc, new_key, val)
        end
      end)

    case is_binary(Enum.at(Map.keys(schema), 0)) do
      true -> Map.merge(schema, %{"airtable_id" => record.id, "inserted_at" => record.createdTime})
      false -> Map.merge(schema, %{airtable_id: record.id, inserted_at: record.createdTime})
    end
  end

end
