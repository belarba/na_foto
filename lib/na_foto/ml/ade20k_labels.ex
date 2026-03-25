defmodule NaFoto.ML.ADE20KLabels do
  @moduledoc """
  ADE20K 150 class labels and grouping into user-friendly categories.
  """

  # ADE20K 150 classes (0-indexed)
  @labels {
    "wall", "building", "sky", "floor", "tree",
    "ceiling", "road", "bed", "windowpane", "grass",
    "cabinet", "sidewalk", "person", "earth", "door",
    "table", "mountain", "plant", "curtain", "chair",
    "car", "water", "painting", "sofa", "shelf",
    "house", "sea", "mirror", "rug", "field",
    "armchair", "seat", "fence", "desk", "rock",
    "wardrobe", "lamp", "bathtub", "railing", "cushion",
    "base", "box", "column", "signboard", "chest of drawers",
    "counter", "sand", "sink", "skyscraper", "fireplace",
    "refrigerator", "grandstand", "path", "stairs", "runway",
    "case", "pool table", "pillow", "screen door", "stairway",
    "river", "bridge", "bookcase", "blind", "coffee table",
    "toilet", "flower", "book", "hill", "bench",
    "countertop", "stove", "palm", "kitchen island", "computer",
    "swivel chair", "boat", "bar", "arcade machine", "hovel",
    "bus", "towel", "light", "truck", "tower",
    "chandelier", "awning", "streetlight", "booth", "television",
    "airplane", "dirt track", "apparel", "pole", "land",
    "bannister", "escalator", "ottoman", "bottle", "buffet",
    "poster", "stage", "van", "ship", "fountain",
    "conveyer belt", "canopy", "washer", "plaything", "swimming pool",
    "stool", "barrel", "basket", "waterfall", "tent",
    "bag", "minibike", "cradle", "oven", "ball",
    "food", "step", "tank", "trade name", "microwave",
    "pot", "animal", "bicycle", "lake", "dishwasher",
    "screen", "blanket", "sculpture", "hood", "sconce",
    "vase", "traffic light", "tray", "ashcan", "fan",
    "pier", "crt screen", "plate", "monitor", "bulletin board",
    "shower", "radiator", "glass", "clock", "flag"
  }

  # Group ADE20K classes into user-friendly categories
  @groups %{
    "construções" => [0, 1, 5, 8, 14, 25, 31, 32, 38, 40, 42, 48, 61, 84],
    "céu" => [2],
    "natureza" => [4, 9, 13, 17, 29, 34, 46, 66, 68, 72, 90, 94],
    "água" => [21, 26, 57, 60, 99, 105, 110, 128],
    "estrada" => [6, 11, 52, 53, 59, 91],
    "pessoas" => [12],
    "veículos" => [20, 76, 80, 83, 86, 97, 98, 107, 127],
    "interior" => [3, 7, 10, 15, 16, 18, 19, 22, 23, 24, 27, 28, 30, 33,
                   35, 36, 37, 39, 41, 43, 44, 45, 47, 49, 50, 51, 55, 56,
                   58, 62, 63, 64, 65, 67, 69, 70, 71, 73, 74, 75, 77, 78,
                   79, 81, 82, 85, 87, 88, 89, 92, 93, 95, 96, 100, 101,
                   102, 103, 104, 106, 108, 109, 111, 112, 113, 114, 115,
                   116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 126,
                   129, 130, 131, 132, 133, 134, 135, 136, 137, 138, 139,
                   140, 141, 142, 143, 144, 145, 146, 147, 148, 149]
  }

  def label(index) when index >= 0 and index < 150 do
    elem(@labels, index)
  end

  def label(_), do: "unknown"

  def groups, do: @groups

  def group_for(index) do
    Enum.find_value(@groups, "outro", fn {group_name, indices} ->
      if index in indices, do: group_name
    end)
  end

  def group_percentages(pixel_counts, total_pixels) do
    @groups
    |> Enum.map(fn {group_name, indices} ->
      count = Enum.reduce(indices, 0, fn idx, acc ->
        acc + Map.get(pixel_counts, idx, 0)
      end)

      percentage = Float.round(count / total_pixels * 100, 1)
      {group_name, percentage}
    end)
    |> Enum.filter(fn {_name, pct} -> pct > 0.1 end)
    |> Enum.sort_by(fn {_name, pct} -> pct end, :desc)
    |> Map.new()
  end
end
