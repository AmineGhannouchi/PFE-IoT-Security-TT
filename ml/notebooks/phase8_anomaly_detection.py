"""
Phase 8 — Détection d'anomalies IoT par Machine Learning
PFE — Sécurisation des flux de communication pour un écosystème IoT simulé
FST / Tunisie Telecom | Amine Ghannouchi
"""

# ─── 0. Imports & Configuration ───────────────────────────────────────────────
import pandas as pd
import numpy as np
import matplotlib
matplotlib.use('Agg')  # mode non-interactif (pas besoin de GUI)
import matplotlib.pyplot as plt
import seaborn as sns
import warnings
import os

from sklearn.ensemble import IsolationForest, RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder
from sklearn.metrics import (
    classification_report, confusion_matrix, roc_auc_score,
    roc_curve, ConfusionMatrixDisplay, f1_score, precision_score, recall_score
)
import joblib

warnings.filterwarnings('ignore')
sns.set_theme(style='whitegrid', palette='muted')
plt.rcParams['figure.dpi'] = 120

# Chemins (relatifs au script, donc depuis ml/notebooks/)
BASE    = os.path.dirname(os.path.abspath(__file__))
DATASET = os.path.join(BASE, '../../datasets/iot_communication_security_dataset_7 (1).csv')
RESULTS = os.path.join(BASE, '../../results/analysis/ml/')
MODELS  = os.path.join(BASE, '../models/')
os.makedirs(RESULTS, exist_ok=True)
os.makedirs(MODELS,  exist_ok=True)

print('Imports OK')
print(f'Results dir : {os.path.abspath(RESULTS)}')
print(f'Models  dir : {os.path.abspath(MODELS)}')

# ─── 1. Chargement & EDA ──────────────────────────────────────────────────────
df = pd.read_csv(DATASET)
print(f'\nShape  : {df.shape}')
print(f'Colonnes : {df.shape[1]}')

print('\n=== Types de données ===')
print(df.dtypes.value_counts())

print('\n=== Valeurs manquantes ===')
missing = df.isnull().sum()
print(missing[missing > 0] if missing.any() else 'Aucune valeur manquante ✅')

# Distribution des classes
fig, axes = plt.subplots(1, 3, figsize=(16, 4))

counts = df['label_secure'].value_counts()
labels = ['Normal (1)', 'Attaque (0)']
axes[0].pie(counts, labels=labels, autopct='%1.1f%%',
            colors=['#2196F3','#F44336'], startangle=90)
axes[0].set_title('Distribution label_secure')

at = df['attack_type'].value_counts()
at.plot(kind='barh', ax=axes[1], color='#FF7043')
axes[1].set_title("Types d'attaques")
axes[1].set_xlabel('Nombre de lignes')

df['protocol'].value_counts().plot(kind='bar', ax=axes[2], color='#42A5F5', rot=0)
axes[2].set_title('Distribution protocoles')
axes[2].set_ylabel('Nombre de lignes')

plt.tight_layout()
plt.savefig(os.path.join(RESULTS, 'eda_classes_distribution.png'), bbox_inches='tight')
plt.close()
print(f'Sauvegardé : eda_classes_distribution.png')

# Statistiques par classe
num_features = ['rtt_ms','jitter_ms','packet_loss_pct','retransmission_count',
                'cpu_usage_pct','mem_usage_pct','failed_auth_1h',
                'conn_attempts_5m','payload_entropy','risk_score',
                'duplicate_msg_rate_pct','anomaly_score_baseline']
print('\n=== Moyenne par label_secure ===')
print(df[num_features + ['label_secure']].groupby('label_secure').mean().T.to_string())

# Heatmap de corrélation
corr = df[num_features].corr()
fig, ax = plt.subplots(figsize=(12, 9))
sns.heatmap(corr, annot=True, fmt='.2f', cmap='coolwarm',
            center=0, linewidths=0.5, ax=ax)
ax.set_title('Matrice de corrélation — Features numériques IoT', fontsize=14)
plt.tight_layout()
plt.savefig(os.path.join(RESULTS, 'eda_correlation_heatmap.png'), bbox_inches='tight')
plt.close()
print('Sauvegardé : eda_correlation_heatmap.png')

# Boxplots
fig, axes = plt.subplots(2, 3, figsize=(16, 9))
features_box = ['rtt_ms','failed_auth_1h','conn_attempts_5m',
                'duplicate_msg_rate_pct','payload_entropy','risk_score']
for ax, feat in zip(axes.flatten(), features_box):
    order = df.groupby('attack_type')[feat].median().sort_values(ascending=False).index
    sns.boxplot(data=df, x='attack_type', y=feat, order=order,
                ax=ax, palette='Set2', fliersize=2)
    ax.set_xticklabels(ax.get_xticklabels(), rotation=30, ha='right', fontsize=8)
    ax.set_title(feat)
    ax.set_xlabel('')
plt.suptitle("Distribution des features clés par type d'attaque", fontsize=13, y=1.01)
plt.tight_layout()
plt.savefig(os.path.join(RESULTS, 'eda_boxplots_by_attack.png'), bbox_inches='tight')
plt.close()
print('Sauvegardé : eda_boxplots_by_attack.png')

# ─── 2. Feature Engineering ───────────────────────────────────────────────────
df_ml = df.copy()

cat_cols = ['protocol','tls_version','auth_method','cert_status',
            'src_zone','dst_zone','message_type','device_type']
le_dict = {}
for col in cat_cols:
    le = LabelEncoder()
    df_ml[col + '_enc'] = le.fit_transform(df_ml[col].astype(str))
    le_dict[col] = le

FEATURES = [
    'payload_bytes','packet_count','session_duration_ms',
    'rtt_ms','jitter_ms','packet_loss_pct','retransmission_count',
    'topic_frequency_1m','duplicate_msg_rate_pct','payload_entropy',
    'qos_level','key_rotation_age_days','firmware_age_days',
    'conn_attempts_5m','failed_auth_1h',
    'anomaly_score_baseline','risk_score',
    'cpu_usage_pct','mem_usage_pct','signal_rssi_dbm','battery_pct',
    'protocol_enc','tls_version_enc','auth_method_enc','cert_status_enc',
    'src_zone_enc','dst_zone_enc','message_type_enc','device_type_enc'
]

X = df_ml[FEATURES]
y = df_ml['label_secure']
y_attack = df_ml['attack_type']

print(f'\nFeatures : {len(FEATURES)}')
print(f'X shape  : {X.shape}')
print(f'y distribution:\n{y.value_counts()}')

# ─── 3. IsolationForest ───────────────────────────────────────────────────────
print('\n' + '='*60)
print('=== IsolationForest (détection non-supervisée) ===')
print('='*60)

X_normal = X[y == 1]
contamination = round(len(y[y==0]) / len(y), 4)
print(f'Entraînement sur {len(X_normal)} lignes normales')
print(f'Contamination estimée : {contamination} ({contamination*100:.1f}%)')

iso_forest = IsolationForest(
    n_estimators=200,
    contamination=contamination,
    max_features=0.8,
    random_state=42,
    n_jobs=-1
)
iso_forest.fit(X_normal)

iso_preds_raw = iso_forest.predict(X)
iso_preds  = np.where(iso_preds_raw == 1, 1, 0)
iso_scores = iso_forest.decision_function(X)

print(f'Prédictions : Normal={( iso_preds==1).sum()}  Attaque={(iso_preds==0).sum()}')

print('\n--- Rapport IsolationForest ---')
print(classification_report(y, iso_preds, target_names=['Attaque (0)', 'Normal (1)']))

iso_f1  = f1_score(y, iso_preds)
iso_roc = roc_auc_score(y, iso_scores)
print(f'F1-score  : {iso_f1:.4f}')
print(f'ROC-AUC   : {iso_roc:.4f}')

# Confusion matrix IsolationForest
fig, ax = plt.subplots(figsize=(5, 4))
ConfusionMatrixDisplay.from_predictions(
    y, iso_preds, display_labels=['Attaque', 'Normal'], cmap='Blues', ax=ax)
ax.set_title(f'IsolationForest — Matrice de confusion\n(F1={iso_f1:.3f}, ROC-AUC={iso_roc:.3f})')
plt.tight_layout()
plt.savefig(os.path.join(RESULTS, 'iso_forest_confusion_matrix.png'), bbox_inches='tight')
plt.close()
print('Sauvegardé : iso_forest_confusion_matrix.png')

# Distribution des scores
fig, ax = plt.subplots(figsize=(10, 4))
ax.hist(iso_scores[y==1], bins=80, alpha=0.6, color='#2196F3', label='Normal', density=True)
ax.hist(iso_scores[y==0], bins=80, alpha=0.6, color='#F44336', label='Attaque', density=True)
ax.axvline(x=0, color='black', linestyle='--', linewidth=1.5, label='Seuil de décision')
ax.set_title("Distribution des scores d'anomalie IsolationForest")
ax.set_xlabel("Score d'anomalie (plus négatif = plus anormal)")
ax.set_ylabel('Densité')
ax.legend()
plt.tight_layout()
plt.savefig(os.path.join(RESULTS, 'iso_forest_scores_distribution.png'), bbox_inches='tight')
plt.close()
print('Sauvegardé : iso_forest_scores_distribution.png')

# ─── 4. RandomForest binaire ──────────────────────────────────────────────────
print('\n' + '='*60)
print('=== RandomForest (classification supervisée — binaire) ===')
print('='*60)

X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42, stratify=y
)
print(f'Train : {X_train.shape[0]}  (attaques={y_train.value_counts()[0]}, normaux={y_train.value_counts()[1]})')
print(f'Test  : {X_test.shape[0]}   (attaques={y_test.value_counts()[0]}, normaux={y_test.value_counts()[1]})')

rf = RandomForestClassifier(
    n_estimators=200, max_depth=20, min_samples_leaf=2,
    class_weight='balanced', random_state=42, n_jobs=-1
)
rf.fit(X_train, y_train)
y_pred  = rf.predict(X_test)
y_proba = rf.predict_proba(X_test)[:, 0]

print('\n--- Rapport RandomForest ---')
print(classification_report(y_test, y_pred, target_names=['Attaque (0)', 'Normal (1)']))

rf_f1  = f1_score(y_test, y_pred)
rf_roc = roc_auc_score(y_test, 1 - y_proba)
print(f'F1-score global : {rf_f1:.4f}')
print(f'ROC-AUC         : {rf_roc:.4f}')

# Confusion matrix + ROC
fig, axes = plt.subplots(1, 2, figsize=(12, 4))
ConfusionMatrixDisplay.from_predictions(
    y_test, y_pred, display_labels=['Attaque', 'Normal'], cmap='Blues', ax=axes[0])
axes[0].set_title(f'RandomForest — Matrice de confusion\n(F1={rf_f1:.3f})')

fpr, tpr, _ = roc_curve(y_test, 1 - y_proba)
axes[1].plot(fpr, tpr, color='#2196F3', lw=2, label=f'ROC-AUC = {rf_roc:.3f}')
axes[1].plot([0,1],[0,1],'k--', lw=1, label='Aléatoire')
axes[1].fill_between(fpr, tpr, alpha=0.1, color='#2196F3')
axes[1].set_xlabel('Taux de faux positifs')
axes[1].set_ylabel('Taux de vrais positifs')
axes[1].set_title('Courbe ROC — RandomForest')
axes[1].legend()
plt.tight_layout()
plt.savefig(os.path.join(RESULTS, 'rf_confusion_roc.png'), bbox_inches='tight')
plt.close()
print('Sauvegardé : rf_confusion_roc.png')

# Feature importance
importances = pd.Series(rf.feature_importances_, index=FEATURES)
top20 = importances.sort_values(ascending=False).head(20)
fig, ax = plt.subplots(figsize=(10, 7))
top20.sort_values().plot(kind='barh', ax=ax, color='#42A5F5')
ax.set_title('Top 20 features — Importance RandomForest', fontsize=13)
ax.set_xlabel('Importance (Gini)')
plt.tight_layout()
plt.savefig(os.path.join(RESULTS, 'rf_feature_importance.png'), bbox_inches='tight')
plt.close()
print('Sauvegardé : rf_feature_importance.png')
print('\nTop 10 features :')
for feat, imp in top20.head(10).items():
    print(f'  {feat:<35} : {imp:.4f}')

# ─── 5. RandomForest multi-classes ────────────────────────────────────────────
print('\n' + '='*60)
print("=== RandomForest Multi-classes (7 types d'attaques) ===")
print('='*60)

le_attack = LabelEncoder()
y_multi = le_attack.fit_transform(y_attack)

X_tr_m, X_te_m, y_tr_m, y_te_m = train_test_split(
    X, y_multi, test_size=0.2, random_state=42, stratify=y_multi
)

rf_multi = RandomForestClassifier(
    n_estimators=200, max_depth=20, class_weight='balanced',
    random_state=42, n_jobs=-1
)
rf_multi.fit(X_tr_m, y_tr_m)
y_pred_m = rf_multi.predict(X_te_m)

print(classification_report(y_te_m, y_pred_m, target_names=le_attack.classes_))

# Confusion matrix multi-classes
fig, ax = plt.subplots(figsize=(9, 7))
cm = confusion_matrix(y_te_m, y_pred_m)
sns.heatmap(cm, annot=True, fmt='d', cmap='Blues',
            xticklabels=le_attack.classes_,
            yticklabels=le_attack.classes_, ax=ax)
ax.set_title('Matrice de confusion — Classification multi-classes', fontsize=13)
ax.set_ylabel('Réel')
ax.set_xlabel('Prédit')
plt.xticks(rotation=30, ha='right')
plt.tight_layout()
plt.savefig(os.path.join(RESULTS, 'rf_multiclass_confusion.png'), bbox_inches='tight')
plt.close()
print('Sauvegardé : rf_multiclass_confusion.png')

# ─── 6. Comparaison des modèles ───────────────────────────────────────────────
print('\n' + '='*60)
print('=== Comparaison des modèles ===')
print('='*60)

results_df = pd.DataFrame({
    'Modèle': ['IsolationForest (non-supervisé)', 'RandomForest (supervisé)'],
    'Précision (attaque)': [
        precision_score(y, iso_preds, pos_label=0),
        precision_score(y_test, y_pred, pos_label=0)
    ],
    'Rappel (attaque)': [
        recall_score(y, iso_preds, pos_label=0),
        recall_score(y_test, y_pred, pos_label=0)
    ],
    'F1-score': [iso_f1, rf_f1],
    'ROC-AUC':  [iso_roc, rf_roc]
})
print(results_df.to_string(index=False))

metrics = ['Précision (attaque)', 'Rappel (attaque)', 'F1-score', 'ROC-AUC']
x = np.arange(len(metrics))
width = 0.35
fig, ax = plt.subplots(figsize=(9, 4))
bars1 = ax.bar(x - width/2, results_df.iloc[0][metrics], width,
               label='IsolationForest', color='#FF7043', alpha=0.85)
bars2 = ax.bar(x + width/2, results_df.iloc[1][metrics], width,
               label='RandomForest',   color='#2196F3', alpha=0.85)
ax.set_xticks(x)
ax.set_xticklabels(metrics)
ax.set_ylim(0, 1.15)
ax.set_ylabel('Score')
ax.set_title("Comparaison IsolationForest vs RandomForest — Détection d'anomalies IoT")
ax.legend()
ax.bar_label(bars1, fmt='%.2f', fontsize=9)
ax.bar_label(bars2, fmt='%.2f', fontsize=9)
plt.tight_layout()
plt.savefig(os.path.join(RESULTS, 'models_comparison.png'), bbox_inches='tight')
plt.close()
print('Sauvegardé : models_comparison.png')

# ─── 7. Sauvegarde des modèles ────────────────────────────────────────────────
joblib.dump(iso_forest,  os.path.join(MODELS, 'isolation_forest.pkl'))
joblib.dump(rf,          os.path.join(MODELS, 'random_forest_binary.pkl'))
joblib.dump(rf_multi,    os.path.join(MODELS, 'random_forest_multiclass.pkl'))
joblib.dump(le_dict,     os.path.join(MODELS, 'label_encoders.pkl'))
joblib.dump(le_attack,   os.path.join(MODELS, 'label_encoder_attack.pkl'))

print('\nModèles sauvegardés :')
for f in sorted(os.listdir(MODELS)):
    size = os.path.getsize(os.path.join(MODELS, f)) / 1024
    print(f'  {f:<45} {size:.0f} Ko')

# ─── Résumé final ─────────────────────────────────────────────────────────────
print('\n' + '='*60)
print('=== RÉSUMÉ FINAL ===')
print('='*60)
print(f'{"Modèle":<35} {"F1-score":>10} {"ROC-AUC":>10}')
print('-'*55)
print(f'{"IsolationForest (non-supervisé)":<35} {iso_f1:>10.4f} {iso_roc:>10.4f}')
print(f'{"RandomForest (supervisé)":<35} {rf_f1:>10.4f} {rf_roc:>10.4f}')
print()
print(f'Figures générées dans : {os.path.abspath(RESULTS)}')
print(f'Modèles sauvegardés  dans : {os.path.abspath(MODELS)}')
print('\n✅ Phase 8 terminée avec succès!')
