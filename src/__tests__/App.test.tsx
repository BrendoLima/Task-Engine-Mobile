/**
 * @format
 */

import React from 'react';
import ReactTestRenderer from 'react-test-renderer';
import App from '../App';

test(
  'renders without crashing',
  async () => {
    let renderer: ReactTestRenderer.ReactTestRenderer | null = null;

    await ReactTestRenderer.act(async () => {
      renderer = ReactTestRenderer.create(<App />);
    });

    await ReactTestRenderer.act(async () => {
      renderer?.unmount();
    });
  },
  30000,
);
