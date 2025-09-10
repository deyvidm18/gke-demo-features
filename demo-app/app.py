from flask import Flask
import math
import signal
import sys

app = Flask(__name__)

# --- ADD THIS SIGNAL HANDLING SECTION ---
# This function will be called when a SIGTERM is received
def handle_sigterm(signal, frame):
    print("SIGTERM received. Application is shutting down gracefully!")
    print("Doing some cleanup logic here...")
    # You could add cleanup logic here, like saving data.
    sys.exit(0) # Exit with a success code

# Register the handler for the SIGTERM signal
signal.signal(signal.SIGTERM, handle_sigterm)
# --- END OF NEW SECTION ---

# This function is computationally expensive and will consume CPU.
def perform_calculation():
    result = 0
    for i in range(1, 200000):
        result += math.sqrt(i) * math.sin(i)
    return result

@app.route('/')
def index():
    return "Web server is running. Hit the /stress endpoint to generate load.", 200

@app.route('/stress')
def stress():
    perform_calculation()
    return "CPU load generated successfully!", 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)