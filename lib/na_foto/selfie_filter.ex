defmodule NaFoto.SelfieFilter do
  @moduledoc """
  Detects selfies using Evision (OpenCV) face detection with Haar Cascades.
  Rejects images where a face occupies more than 15% of the total image area.
  """

  alias Evision, as: Cv

  @face_area_threshold 0.15

  @doc """
  Checks if an image is a selfie.
  Returns :ok if not a selfie, {:error, :selfie_detected} if it is.
  """
  def check(image_path) when is_binary(image_path) do
    case Cv.imread(image_path) do
      %Cv.Mat{} = img -> do_check(img)
      {:error, _reason} -> :ok
    end
  end

  defp do_check(img) do
    {h, w, _} = Cv.Mat.shape(img)
    total_area = h * w

    gray = Cv.cvtColor(img, Cv.Constant.cv_COLOR_BGR2GRAY())

    cascade_path =
      Path.join(
        :code.priv_dir(:evision),
        "share/opencv4/haarcascades/haarcascade_frontalface_default.xml"
      )

    if File.exists?(cascade_path) do
      cascade = Cv.CascadeClassifier.cascadeClassifier(cascade_path)

      case Cv.CascadeClassifier.detectMultiScale(cascade, gray,
             scaleFactor: 1.1,
             minNeighbors: 5,
             minSize: {30, 30}
           ) do
        faces when is_list(faces) and faces != [] ->
          max_face_ratio =
            faces
            |> Enum.map(fn {_x, _y, fw, fh} -> fw * fh / total_area end)
            |> Enum.max()

          if max_face_ratio > @face_area_threshold do
            {:error, :selfie_detected}
          else
            :ok
          end

        # Evision may return a Mat instead of a list
        %Cv.Mat{} = mat ->
          result = Cv.Mat.to_nx(mat, Nx.BinaryBackend)

          case Nx.shape(result) do
            {0, _} ->
              :ok

            {n, 4} when n > 0 ->
              rects = Nx.to_list(result)

              max_face_ratio =
                rects
                |> Enum.map(fn [_x, _y, fw, fh] -> fw * fh / total_area end)
                |> Enum.max()

              if max_face_ratio > @face_area_threshold do
                {:error, :selfie_detected}
              else
                :ok
              end

            _ ->
              :ok
          end

        _ ->
          :ok
      end
    else
      :ok
    end
  end
end
