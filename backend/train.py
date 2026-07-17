import pandas as pd
# pyrefly: ignore [missing-import]
import numpy as np
from sklearn.linear_model import LogisticRegression
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score
import pickle
# Step 1: Dataset load karo
df = pd.read_csv("dataset.csv")
# Step 2: Saare unique symptoms nikalo
symptom_cols = [col for col in df.columns if col != "Disease"]
all_symptoms = set()
for col in symptom_cols:
    all_symptoms.update(df[col].dropna().str.strip().unique())
all_symptoms = sorted(list(all_symptoms))
print(f"Total symptoms: {len(all_symptoms)}")
# Step 3: One Hot Encoding karo
def encode_row(row):
    present = set(str(s).strip() for s in row if pd.notna(s))
    return [1 if s in present else 0 for s in all_symptoms]
X = pd.DataFrame(
    [encode_row(df[symptom_cols].iloc[i]) for i in range(len(df))],
    columns=all_symptoms
)
y = df["Disease"]
# Step 4: Train test split
X_train, X_test, y_train, y_test = train_test_split(
    X, y,
    test_size=0.2,
    random_state=42
)
# Step 5: Model train karo
model = LogisticRegression(max_iter=1000)
model.fit(X_train, y_train)
print("Training done! ✅")

# Step 6: Accuracy check karo
y_pred = model.predict(X_test)
accuracy = accuracy_score(y_test, y_pred)
print(f"Accuracy: {accuracy * 100:.2f}%")

# Step 7: Model aur symptoms save karo
pickle.dump(model, open("model.pkl", "wb"))
pickle.dump(all_symptoms, open("symptoms.pkl", "wb"))
print("Model saved! ✅")