# pyrefly: ignore [missing-import]
from flask import Flask, request, jsonify
from flask_cors import CORS
import pickle

app = Flask(__name__)
CORS(app)  # Allow Flutter web and mobile to call the API

# Load the trained model and the ordered list of all symptoms
model = pickle.load(open("model.pkl", "rb"))
all_symptoms = pickle.load(open("symptoms.pkl", "rb"))

# In-memory store for the last prediction (one session at a time)
_last_prediction = {"disease": None}


@app.route('/health', methods=['GET'])
def health():
    """Health-check endpoint — Flutter calls this to verify the server is up."""
    return jsonify({"status": "ok", "symptom_count": len(all_symptoms)})


@app.route('/predict', methods=['POST'])
def submit_symptoms():
    """
    POST /predict
    Accept a flat JSON map of {symptom_name: 0_or_1} (exactly what Flutter sends).
    Builds the input vector, runs the ML model, stores the prediction,
    and returns it immediately.

    Example body Flutter sends:
    {
      "itching": 1,
      "skin_rash": 1,
      "headache": 0,
      ...
    }
    """
    if not request.is_json:
        return jsonify({"success": False, "error": "Request must be JSON"}), 400

    data = request.get_json(silent=True)
    if data is None:
        return jsonify({"success": False, "error": "Invalid JSON body"}), 400

    # Build input vector from the flat symptom map Flutter sends
    # Each element is 1 if that symptom key is present and set to 1, else 0
    input_vector = [int(data.get(symptom, 0)) for symptom in all_symptoms]

    try:
        prediction = model.predict([input_vector])
        disease = str(prediction[0]).strip()
        _last_prediction["disease"] = disease
        return jsonify({"success": True, "disease": disease})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


@app.route('/predict', methods=['GET'])
def get_prediction():
    """
    GET /predict
    Returns the last stored prediction.
    Flutter calls this after the POST to retrieve the disease name.
    """
    if _last_prediction["disease"] is None:
        return jsonify({"success": False, "error": "No prediction yet. POST symptoms first."}), 404
    return jsonify({"success": True, "disease": _last_prediction["disease"]})


if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=5000)