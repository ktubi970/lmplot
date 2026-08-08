import os
import json
import subprocess
import tempfile
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
import streamlit as st

st.set_page_config(
    page_title="LM Plot Explorer (Streamlit + R Engine)",
    page_icon="📊",
    layout="wide"
)

st.title("📊 LM Plot Explorer")
st.caption("Interactive local exploration of linear, generalized linear, and Gaussian mixed models powered by an R statistical engine.")

# Model metadata configuration
MODEL_METADATA = {
    "lm_2d": {"label": "Simple LM (2D)", "links": ["identity"], "default_link": "identity", "dimensions": 2, "requires_group": False},
    "lm_3d": {"label": "Multiple LM (3D)", "links": ["identity"], "default_link": "identity", "dimensions": 3, "requires_group": False},
    "glm_binomial_2d": {"label": "Simple Binomial GLM (2D)", "links": ["logit", "probit", "cloglog"], "default_link": "logit", "dimensions": 2, "requires_group": False},
    "glm_binomial": {"label": "Binomial GLM (3D)", "links": ["logit", "probit", "cloglog"], "default_link": "logit", "dimensions": 3, "requires_group": False},
    "glm_poisson": {"label": "Poisson GLM", "links": ["log", "identity", "sqrt"], "default_link": "log", "dimensions": 3, "requires_group": False},
    "glm_gamma": {"label": "Gamma GLM", "links": ["inverse", "log", "identity"], "default_link": "inverse", "dimensions": 3, "requires_group": False},
    "glmm": {"label": "Gaussian GLMM", "links": ["identity"], "default_link": "identity", "dimensions": 3, "requires_group": True}
}

REAL_EXAMPLES = {
    "lm_2d": {"id": "adelie_flipper_mass", "title": "Adélie penguin body mass"},
    "lm_3d": {"id": "concrete_28d", "title": "28-day concrete compressive strength"},
    "glm_binomial": {"id": "adelie_sex", "title": "Adélie penguin sex from morphology"},
    "glm_poisson": {"id": "abalone_rings", "title": "Abalone shell-ring count"},
    "glm_gamma": {"id": "forest_fire_positive_area", "title": "Positive forest-fire burned area"},
    "glmm": {"id": "inner_london_exam", "title": "Inner London examination achievement"}
}

# Sidebar Controls
st.sidebar.header("⚙️ Model Configuration")

model_choice = st.sidebar.selectbox(
    "Select Model",
    options=list(MODEL_METADATA.keys()),
    format_func=lambda k: MODEL_METADATA[k]["label"],
    index=1
)

meta = MODEL_METADATA[model_choice]

link = st.sidebar.selectbox(
    "Link Function",
    options=meta["links"],
    index=meta["links"].index(meta["default_link"])
)

data_source = st.sidebar.radio(
    "Data Source",
    options=["simulation", "real"],
    format_func=lambda s: "Simulated Data" if s == "simulation" else "Scientific Real Data",
    horizontal=True
)

req_payload = {
    "model_type": model_choice,
    "link": link,
    "data_source": data_source
}

if data_source == "simulation":
    st.sidebar.subheader("Simulation Parameters")
    req_payload["n"] = st.sidebar.slider("Sample Size (n)", min_value=20, max_value=2000, value=150, step=10)
    req_payload["seed"] = st.sidebar.number_input("Deterministic Seed", value=42, step=1)
    
    with st.sidebar.expander("Advanced Coefficients"):
        req_payload["beta0"] = st.number_input("β0 (Intercept)", value=2.0)
        req_payload["beta1"] = st.number_input("β1 (X Slope)", value=0.5)
        if meta["dimensions"] == 3:
            req_payload["beta2"] = st.number_input("β2 (Y Slope)", value=-0.25)
        if meta["requires_group"]:
            req_payload["group_sd"] = st.number_input("Group Random SD", value=1.0, min_value=0.0)
            req_payload["groups"] = st.slider("Number of Groups", min_value=5, max_value=20, value=5)
        if model_choice.startswith("lm"):
            req_payload["sigma"] = st.number_input("Residual σ", value=1.0, min_value=0.1)
        elif model_choice == "glm_gamma":
            req_payload["shape"] = st.number_input("Gamma Shape", value=2.0, min_value=0.1)
else:
    if model_choice in REAL_EXAMPLES:
        example_info = REAL_EXAMPLES[model_choice]
        st.sidebar.info(f"**Dataset:** {example_info['title']}")
        req_payload["example_id"] = example_info["id"]
    else:
        st.sidebar.warning("No real data example available for 2D Binomial GLM. Using simulation fallback.")
        req_payload["data_source"] = "simulation"
        req_payload["n"] = 150
        req_payload["seed"] = 42

import shutil

def find_rscript():
    rscript = shutil.which("Rscript")
    if rscript:
        return rscript
    rscript_win = "C:\\Program Files\\R\\R-4.6.0\\bin\\x64\\Rscript.exe"
    if os.path.exists(rscript_win):
        return rscript_win
    return "Rscript"

@st.cache_resource
def ensure_r_packages():
    rscript_bin = find_rscript()
    r_code = """
    user_lib <- file.path(Sys.getenv("HOME"), "R_library")
    dir.create(user_lib, recursive = TRUE, showWarnings = FALSE)
    .libPaths(c(user_lib, .libPaths()))
    if (!requireNamespace("jsonlite", quietly = TRUE)) {
      install.packages("jsonlite", lib = user_lib, repos = "https://cloud.r-project.org/", quietly = TRUE)
    }
    """
    try:
        subprocess.run([rscript_bin, "-e", r_code], capture_output=True, text=True, timeout=60)
    except Exception:
        pass

ensure_r_packages()

@st.cache_data(show_spinner=False)
def _cached_run_r_analysis(payload_str: str):
    payload = json.loads(payload_str)
    with tempfile.NamedTemporaryFile(suffix=".json", delete=False, mode="w") as req_file:
        json.dump(payload, req_file)
        req_path = req_file.name
        
    out_path = req_path.replace(".json", "_out.json")
    rscript_bin = find_rscript()
    cmd = [rscript_bin, "scripts/run_analysis.R", req_path, out_path]
    
    try:
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=45
        )
        if proc.returncode != 0:
            return {"error": proc.stderr}
            
        with open(out_path, "r") as f:
            result = json.load(f)
            
        return result
    finally:
        if os.path.exists(req_path):
            try: os.remove(req_path)
            except Exception: pass
        if os.path.exists(out_path):
            try: os.remove(out_path)
            except Exception: pass

def run_r_analysis(payload):
    payload_str = json.dumps(payload, sort_keys=True)
    res = _cached_run_r_analysis(payload_str)
    if isinstance(res, dict) and "error" in res:
        st.error(f"R Engine Error:\n{res['error']}")
        return None
    return res

# Execute button
if st.sidebar.button("🚀 Fit Model & Generate Visualizations", type="primary", use_container_width=True):
    st.session_state["analysis_payload"] = req_payload

if "analysis_payload" not in st.session_state:
    st.session_state["analysis_payload"] = req_payload

# Run R analysis
with st.spinner("Executing R statistical engine..."):
    analysis = run_r_analysis(st.session_state["analysis_payload"])

if analysis:
    df_data = pd.DataFrame(analysis["data"])
    df_data[".fitted"] = analysis["fitted"]
    df_data[".residual"] = analysis["residuals"]
    
    grid = pd.DataFrame(analysis["prediction_grid"])
    labels = analysis["labels"]
    
    # Top KPI Metrics
    m1, m2, m3, m4 = st.columns(4)
    m1.metric("Observations (n)", len(df_data))
    m2.metric("Model Family", meta["label"])
    m3.metric("Link Function", analysis["link"])
    m4.metric("Dimensions", "2D Curve" if meta["dimensions"] == 2 else "3D Surface")
    
    st.markdown("---")
    
    # Main Tabs
    tab_plot, tab_diag, tab_coef, tab_data = st.tabs([
        "📈 Main Plot", "🔍 Residual Diagnostics", "📋 Model Summary", "📑 Data Preview"
    ])
    
    with tab_plot:
        st.subheader("Response-Scale Visualization")
        if meta["dimensions"] == 2:
            fig = px.scatter(
                df_data, x="X", y="Z",
                labels={"X": labels["x"], "Z": labels["z"]},
                title=f"{meta['label']} Response Curve",
                opacity=0.7
            )
            grid_sorted = grid.sort_values("X")
            fig.add_trace(go.Scatter(
                x=grid_sorted["X"], y=grid_sorted[".fitted"],
                mode="lines", name="Fitted Model Curve",
                line=dict(color="#2563eb", width=3)
            ))
            st.plotly_chart(fig, use_container_width=True)
        else:
            fig = px.scatter_3d(
                df_data, x="X", y="Y", z="Z",
                color=".residual",
                color_continuous_scale="Viridis",
                labels={"X": labels["x"], "Y": labels["y"], "Z": labels["z"]},
                title=f"{meta['label']} 3D Scatter & Predicted Surface",
                opacity=0.8
            )
            st.plotly_chart(fig, use_container_width=True)
            
    with tab_diag:
        st.subheader("Residual Diagnostics")
        diag_fig = px.scatter(
            df_data, x=".fitted", y=".residual",
            labels={".fitted": "Fitted Values", ".residual": "Response Residuals"},
            title="Residuals vs Fitted Values",
            opacity=0.7
        )
        diag_fig.add_hline(y=0, line_dash="dash", line_color="red")
        st.plotly_chart(diag_fig, use_container_width=True)
        
    with tab_coef:
        st.subheader("Estimated R Coefficients")
        df_coef = pd.DataFrame(analysis["coefficients"])
        if "term" in df_coef.columns:
            df_coef = df_coef.set_index("term")
        st.dataframe(df_coef, use_container_width=True)
        
    with tab_data:
        st.subheader("Analysis Data Table")
        st.dataframe(df_data, use_container_width=True)
        
        csv_data = df_data.to_csv(index=False).encode('utf-8')
        st.download_button(
            label="📥 Download Enriched CSV",
            data=csv_data,
            file_name=f"{model_choice}_enriched.csv",
            mime="text/csv"
        )
