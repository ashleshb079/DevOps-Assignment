import { useState, useEffect } from 'react';
import Head from 'next/head';
import axios from 'axios';

export default function Home() {
  const [message, setMessage] = useState('Loading...');
  const [status, setStatus] = useState('');
  const [apiUrl, setApiUrl] = useState('');

  useEffect(() => {
    const API = process.env.NEXT_PUBLIC_API_URL;

    console.log("API URL:", API); // DEBUG check

    if (!API) {
      setStatus('API URL not configured');
      setMessage('Missing backend configuration');
      return;
    }

    setApiUrl(API);

    const fetchData = async () => {
      try {
        // Health check
        const healthCheck = await axios.get(`${API}/api/health`);

        if (healthCheck.data.status === 'healthy') {
          setStatus('Backend is connected!');

          // Fetch message
          const response = await axios.get(`${API}/api/message`);
          setMessage(response.data.message);
        } else {
          setStatus('Backend not healthy');
          setMessage('Health check failed');
        }
      } catch (error) {
        setStatus('Backend connection failed');
        setMessage('Failed to connect to backend');
        console.error('Error:', error);
      }
    };

    fetchData();
  }, []);

  return (
    <div className="container">
      <Head>
        <title>DevOps Assignment</title>
        <meta name="description" content="DevOps Assignment with FastAPI and Next.js" />
        <link rel="icon" href="/favicon.ico" />
      </Head>

      <main>
        <h1>DevOps Assignments</h1>

        <div className="status">
          <p>
            Status:{' '}
            <span className={status.includes('connected') ? 'success' : 'error'}>
              {status}
            </span>
          </p>
        </div>

        <div className="message-box">
          <h2>Backend Message:</h2>
          <p>{message}</p>
        </div>

        <div className="info">
          <p>Backend URL: {apiUrl}</p>
        </div>
      </main>

      <style jsx>{`
        .container {
          min-height: 100vh;
          padding: 0 0.5rem;
          display: flex;
          flex-direction: column;
          justify-content: center;
          align-items: center;
        }

        main {
          padding: 5rem 0;
          flex: 1;
          display: flex;
          flex-direction: column;
          justify-content: center;
          align-items: center;
          max-width: 800px;
          margin: 0 auto;
          text-align: center;
        }

        h1 {
          margin: 0;
          line-height: 1.15;
          font-size: 3rem;
          margin-bottom: 2rem;
        }

        .message-box {
          margin: 2rem 0;
          padding: 1.5rem;
          border: 1px solid #eaeaea;
          border-radius: 10px;
          width: 100%;
          max-width: 600px;
        }

        .success {
          color: #0070f3;
          font-weight: bold;
        }

        .error {
          color: #f00;
          font-weight: bold;
        }

        .info {
          margin-top: 2rem;
          font-size: 0.9rem;
          color: #666;
        }
      `}</style>
    </div>
  );
}